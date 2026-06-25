import '../../core/compat/io_compat.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_refresh_provider.dart';
import '../../core/providers/project_providers.dart';
import '../../data/repositories/assignments_repository.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../ui/theme/sao_colors.dart';
import '../auth/app_session_controller.dart';
import '../completed_activities/completed_activities_provider.dart';
import '../reports/reports_provider.dart';
import 'dashboard_provider.dart';
import '../../core/utils/project_terminology.dart';

String _sanitizePdfFolderSegment(String raw, {String fallback = 'SIN_DATO'}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  final sanitized = trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty) return fallback;
  return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80).trim();
}

bool _isPdfEvidenceItem(EvidenceItem evidence) {
  final typeToken = evidence.type.trim().toUpperCase();
  final pathToken = evidence.gcsPath.trim().toLowerCase();
  return typeToken.contains('PDF') ||
      typeToken.contains('DOCUMENT') ||
      pathToken.endsWith('.pdf');
}

EvidenceItem? _selectPdfEvidenceForDownload(CompletedActivityDetail detail) {
  final candidates = <EvidenceItem>[
    ...detail.documents,
    ...detail.evidences.where(_isPdfEvidenceItem),
  ];
  if (candidates.isEmpty) return null;
  candidates.sort((left, right) {
    final leftDate = DateTime.tryParse(left.uploadedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = DateTime.tryParse(right.uploadedAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  });
  return candidates.first;
}

String _inferPdfFileName(EvidenceItem evidence, String activityId) {
  final normalized = evidence.gcsPath.trim().replaceAll('\\', '/');
  if (normalized.isNotEmpty) {
    final segments = normalized.split('/');
    final candidate = segments.isEmpty ? '' : segments.last.trim();
    if (candidate.isNotEmpty) return candidate;
  }
  return 'reporte_${activityId.trim()}.pdf';
}

/// Carga una fuente TTF del sistema con soporte Unicode para el PDF.
/// Retorna null si no se puede cargar (fallback a Helvetica).
Future<pw.Font?> _loadSystemPdfFont(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return pw.Font.ttf(bytes.buffer.asByteData());
    }
  } catch (_) {}
  return null;
}

Future<String> _resolveDashboardDocumentsRootPath() async {
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

Future<bool> _openDashboardLocalPath(String path) async {
  final trimmedPath = path.trim();
  if (trimmedPath.isEmpty) return false;

  try {
    final opened = await launchUrl(
      Uri.file(trimmedPath),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return true;
  } catch (_) {
    // Fall back to native desktop commands below.
  }

  try {
    late final ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [trimmedPath]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', trimmedPath]);
    } else {
      result = await Process.run('xdg-open', [trimmedPath]);
    }
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

String _dashboardCanonicalToken(String raw) {
  final replacements = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };

  final folded = raw
      .trim()
      .toLowerCase()
      .split('')
      .map((char) => replacements[char] ?? char)
      .join();

  return folded
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String normalizeDashboardRiskToken(String raw) {
  switch (_dashboardCanonicalToken(raw)) {
    case 'low':
    case 'bajo':
      return 'bajo';
    case 'medium':
    case 'medio':
      return 'medio';
    case 'high':
    case 'alto':
      return 'alto';
    case 'critical':
    case 'critico':
    case 'prioridad_alta':
    case 'priority':
    case 'prioritario':
      return 'prioritario';
    default:
      return _dashboardCanonicalToken(raw);
  }
}

String normalizeDashboardReviewStatus(String raw) {
  switch (_dashboardCanonicalToken(raw)) {
    case 'aprobada':
    case 'aprobado':
    case 'approved':
    case 'approve':
      return 'APROBADO';
    case 'rechazada':
    case 'rechazado':
    case 'rejected':
    case 'reject':
      return 'RECHAZADO';
    case 'pendiente':
    case 'pending':
    case 'en_revision':
    case 'pendiente_revision':
    case 'revision_pendiente':
    case 'pending_review':
    case 'pending_approval':
      return 'PENDIENTE_REVISION';
    case '':
      return '';
    default:
      return _dashboardCanonicalToken(raw).toUpperCase();
  }
}

String normalizeDashboardExecutionStatus(String raw) {
  switch (_dashboardCanonicalToken(raw)) {
    case 'aprobada':
    case 'aprobado':
    case 'approved':
    case 'completed':
    case 'completada':
      return 'COMPLETADA';
    case 'rechazada':
    case 'rechazado':
    case 'rejected':
      return 'RECHAZADO';
    case 'en_curso':
    case 'in_progress':
    case 'needs_fix':
    case 'necesita_correccion':
      return 'EN_CURSO';
    case 'en_revision':
    case 'pendiente_revision':
    case 'revision_pendiente':
    case 'pending_review':
    case 'pending_approval':
      return 'REVISION_PENDIENTE';
    case 'programada':
    case 'pendiente':
    case 'pending':
      return 'PENDIENTE';
    case '':
      return '';
    default:
      return _dashboardCanonicalToken(raw).toUpperCase();
  }
}

String dashboardNormalizeSearchToken(String raw) {
  return _dashboardCanonicalToken(raw).replaceAll('_', ' ');
}

List<String> dashboardSearchTermsFromQuery(String raw) {
  return raw
      .split('|')
      .map(dashboardNormalizeSearchToken)
      .where((value) => value.trim().isNotEmpty)
      .toList(growable: false);
}

bool dashboardMatchesSearchQuery(String searchable, String rawQuery) {
  final terms = dashboardSearchTermsFromQuery(rawQuery);
  if (terms.isEmpty) return true;
  return terms.every(searchable.contains);
}

String cleanDashboardFilterValue(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return '';
  return trimmed;
}

String cleanDashboardUserName(String raw) {
  return cleanDashboardFilterValue(raw);
}

bool dashboardMatchesValueFilter(String? candidateValue, String? selectedValue) {
  final selected = cleanDashboardFilterValue(selectedValue ?? '');
  final normalizedSelected = _dashboardCanonicalToken(selected);
  if (selected.isEmpty ||
      normalizedSelected.isEmpty ||
      normalizedSelected == 'todo' ||
      normalizedSelected == 'todos' ||
      normalizedSelected == 'todas') {
    return true;
  }
  final candidate = cleanDashboardFilterValue(candidateValue ?? '');
  if (candidate.isEmpty) return false;
  return _dashboardCanonicalToken(candidate) == normalizedSelected;
}

bool dashboardMatchesUserFilter(String? candidateName, String? selectedUser) {
  return dashboardMatchesValueFilter(candidateName, selectedUser);
}

List<String> resolveDashboardFilterOptions({
  List<String> preferredValues = const [],
  Iterable<String> candidateValues = const [],
}) {
  final seen = <String>{};
  final values = <String>[];

  void addValue(String raw) {
    final clean = cleanDashboardFilterValue(raw);
    if (clean.isEmpty) return;
    final token = _dashboardCanonicalToken(clean);
    if (token.isEmpty || !seen.add(token)) return;
    values.add(clean);
  }

  for (final value in preferredValues) {
    addValue(value);
  }
  for (final value in candidateValues) {
    addValue(value);
  }

  values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return <String>['Todo', ...values];
}

List<String> resolveDashboardUserOptions({
  List<String> projectUsers = const [],
  required List<ValidationQueueItem> queueItems,
  required List<DashboardGeoPoint> geoPoints,
}) {
  return resolveDashboardFilterOptions(
    preferredValues: projectUsers,
    candidateValues: [
      ...queueItems.map((item) => item.userName),
      ...geoPoints.map((point) => point.assignedName ?? ''),
    ],
  );
}

final dashboardProjectUsersProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  final selectedProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
  final availableProjects = ref.watch(availableProjectsProvider).valueOrNull ?? const <String>[];

  final projects = <String>{
    if (selectedProjectId.isNotEmpty)
      selectedProjectId
    else
      ...availableProjects
          .map((projectId) => projectId.trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
  }.toList(growable: false);

  if (projects.isEmpty) return const [];

  final users = <String>{};
  for (final projectId in projects) {
    try {
      final members = await repo.getTransferCandidates(projectId);
      for (final member in members) {
        final displayName = cleanDashboardUserName(member.fullName);
        if (displayName.isNotEmpty) {
          users.add(displayName);
          continue;
        }
        final email = cleanDashboardUserName(member.email);
        if (email.isNotEmpty) {
          users.add(email);
        }
      }
    } catch (_) {
      // Graceful fallback handled by current dashboard data.
    }
  }

  final result = users.toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
});

final dashboardProjectFrontsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  final selectedProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
  final availableProjects = ref.watch(availableProjectsProvider).valueOrNull ?? const <String>[];

  final projects = <String>{
    if (selectedProjectId.isNotEmpty)
      selectedProjectId
    else
      ...availableProjects
          .map((projectId) => projectId.trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
  }.toList(growable: false);

  if (projects.isEmpty) return const [];

  final fronts = <String>{};
  for (final projectId in projects) {
    try {
      final values = await repo.getFronts(projectId);
      for (final front in values) {
        final displayName = cleanDashboardFilterValue(
          front.name.isNotEmpty ? front.name : front.code,
        );
        if (displayName.isNotEmpty) {
          fronts.add(displayName);
        }
      }
    } catch (_) {
      // Graceful fallback handled by current dashboard data.
    }
  }

  final result = fronts.toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
});

class _DashboardProjectCoverageOptions {
  final List<String> states;
  final List<String> municipalities;
  final Map<String, List<String>> municipalitiesByState;

  const _DashboardProjectCoverageOptions({
    required this.states,
    required this.municipalities,
    required this.municipalitiesByState,
  });

  List<String> municipalitiesForState(String state) {
    if (dashboardMatchesValueFilter('', state)) {
      return municipalities;
    }
    final result = <String>{};
    for (final entry in municipalitiesByState.entries) {
      if (dashboardMatchesValueFilter(entry.key, state)) {
        result.addAll(entry.value);
      }
    }
    final values = result.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }
}

final dashboardProjectCoverageOptionsProvider = FutureProvider.autoDispose<_DashboardProjectCoverageOptions>((ref) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  final selectedProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
  final availableProjects = ref.watch(availableProjectsProvider).valueOrNull ?? const <String>[];

  final projects = <String>{
    if (selectedProjectId.isNotEmpty)
      selectedProjectId
    else
      ...availableProjects
          .map((projectId) => projectId.trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
  }.toList(growable: false);

  if (projects.isEmpty) {
    return const _DashboardProjectCoverageOptions(
      states: [],
      municipalities: [],
      municipalitiesByState: {},
    );
  }

  final states = <String>{};
  final municipalities = <String>{};
  final municipalitiesByState = <String, Set<String>>{};

  for (final projectId in projects) {
    try {
      final coverageByFront = await repo.getFrontCoverageByFront(projectId);
      for (final options in coverageByFront.values) {
        for (final option in options) {
          final state = cleanDashboardFilterValue(option.estado);
          final municipality = cleanDashboardFilterValue(option.municipio);
          if (state.isNotEmpty) {
            states.add(state);
          }
          if (municipality.isNotEmpty) {
            municipalities.add(municipality);
            if (state.isNotEmpty) {
              municipalitiesByState.putIfAbsent(state, () => <String>{}).add(municipality);
            }
          }
        }
      }
    } catch (_) {
      // Graceful fallback handled by current dashboard data.
    }
  }

  final sortedStates = states.toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final sortedMunicipalities = municipalities.toList(growable: false)
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return _DashboardProjectCoverageOptions(
    states: sortedStates,
    municipalities: sortedMunicipalities,
    municipalitiesByState: {
      for (final entry in municipalitiesByState.entries)
        entry.key: (entry.value.toList(growable: false)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    },
  );
});

bool dashboardMatchesKpiFilter(ValidationQueueItem item, DashboardKpiFilter filter) {
  final normalizedStatus = normalizeDashboardExecutionStatus(item.status);
  return switch (filter) {
    DashboardKpiFilter.all => true,
    DashboardKpiFilter.pending =>
      normalizedStatus == 'PENDIENTE' || normalizedStatus == 'REVISION_PENDIENTE',
    DashboardKpiFilter.approved => normalizedStatus == 'COMPLETADA',
    DashboardKpiFilter.rejected => normalizedStatus == 'RECHAZADO',
    DashboardKpiFilter.needsFix => normalizedStatus == 'EN_CURSO',
  };
}

bool isCriticalDashboardQueueItem(ValidationQueueItem item) {
  final normalizedRisk = normalizeDashboardRiskToken(item.risk);
  return normalizedRisk == 'alto' ||
      normalizedRisk == 'prioritario' ||
      item.hasConflicts;
}

String dashboardEffectiveMapStatus(DashboardGeoPoint point) {
  final reviewStatus = normalizeDashboardReviewStatus(point.reviewStatus);
  final reviewDecision = normalizeDashboardReviewStatus(point.reviewDecision ?? '');
  if (reviewStatus == 'APROBADO' || reviewDecision == 'APROBADO') {
    return 'COMPLETADA';
  }
  if (reviewStatus == 'RECHAZADO' || reviewDecision == 'RECHAZADO') {
    return 'RECHAZADO';
  }
  return normalizeDashboardExecutionStatus(point.status);
}

bool dashboardPointMatchesPlanningFilters(
  DashboardGeoPoint item, {
  required String statusFilter,
  required String riskFilter,
  required String reviewFilter,
  required String userFilter,
  required String frontFilter,
  required String stateFilter,
  required String municipalityFilter,
  required String searchQuery,
}) {
  final normalizedStatusFilter = statusFilter == 'todos'
      ? 'todos'
      : normalizeDashboardExecutionStatus(statusFilter);
  final normalizedRiskFilter = riskFilter == 'todos'
      ? 'todos'
      : normalizeDashboardRiskToken(riskFilter);
  final normalizedReviewFilter = reviewFilter == 'todos'
      ? 'todos'
      : normalizeDashboardReviewStatus(reviewFilter);

  final byStatus = normalizedStatusFilter == 'todos' ||
      dashboardEffectiveMapStatus(item) == normalizedStatusFilter;
  final byRisk = normalizedRiskFilter == 'todos' ||
      normalizeDashboardRiskToken(item.risk) == normalizedRiskFilter;
  final byReview = normalizedReviewFilter == 'todos' ||
      normalizeDashboardReviewStatus(item.reviewStatus) == normalizedReviewFilter ||
      normalizeDashboardReviewStatus(item.reviewDecision ?? '') == normalizedReviewFilter;

  final searchable = dashboardNormalizeSearchToken(
    [
      item.label,
      item.front,
      item.municipality,
      item.state,
      item.assignedName ?? '',
    ].join(' '),
  );
  final bySearch = dashboardMatchesSearchQuery(searchable, searchQuery);
  final byUser = dashboardMatchesUserFilter(item.assignedName, userFilter);
  final byFront = dashboardMatchesValueFilter(item.front, frontFilter);
  final byState = dashboardMatchesValueFilter(item.state, stateFilter);
  final byMunicipality = dashboardMatchesValueFilter(item.municipality, municipalityFilter);

  return byStatus && byRisk && byReview && bySearch && byUser && byFront && byState && byMunicipality;
}

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DashboardKpiFilter _kpiFilter = DashboardKpiFilter.all;
  String _planningStatusFilter = 'todos';
  final String _planningRiskFilter = 'todos';
  final String _planningReviewFilter = 'todos';
  String _planningUserFilter = 'Todo';
  final String _planningFrontFilter = 'Todo';
  final String _planningStateFilter = 'Todo';
  final String _planningMunicipalityFilter = 'Todo';
  final List<String> _searchFilterTags = [];
  final TextEditingController _searchFilterController = TextEditingController();
  String? _selectedMapPointId;
  final ScrollController _frontProgressScrollController = ScrollController();
  final ScrollController _mapLocationsScrollController = ScrollController();

  @override
  void dispose() {
    _searchFilterController.dispose();
    _frontProgressScrollController.dispose();
    _mapLocationsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(selectedDashboardRangeProvider);
    final selectedProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
    final availableProjectsAsync = ref.watch(availableProjectsProvider);
    final availableProjects = (availableProjectsAsync.valueOrNull ?? const <String>[])
        .map((raw) => raw.trim().toUpperCase())
        .where((raw) => raw.isNotEmpty)
        .toSet();
    // Solo agregar el proyecto activo si pertenece a la lista accesible del usuario.
    if (selectedProjectId.isNotEmpty && availableProjects.isNotEmpty &&
        !availableProjects.contains(selectedProjectId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeProjectIdProvider.notifier).select(availableProjects.first);
      });
    }
    final projectOptions = availableProjects.toList()..sort();
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: SaoColors.scaffoldBackgroundFor(context),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No se pudo cargar el dashboard: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (data) {
          final projectUsers = ref.watch(dashboardProjectUsersProvider).valueOrNull ?? const <String>[];
          final userOptions = resolveDashboardUserOptions(
            projectUsers: projectUsers,
            queueItems: data.queueItems,
            geoPoints: data.geoPoints,
          );
          final dashboardView = _buildFilteredDashboardData(data);
          final filteredQueue = _applyFilters(data.queueItems);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(dashboardView, range, selectedProjectId, projectOptions, userOptions),
                  const SizedBox(height: 16),
                  _buildKpis(context, dashboardView),
                  const SizedBox(height: 16),
                  _buildDashboardFiltersCard(data),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 1200;
                      if (isCompact) {
                        return Column(
                          children: [
                            _buildStatusOverviewCard(dashboardView),
                            const SizedBox(height: 16),
                            _buildProgressCard(dashboardView),
                            const SizedBox(height: 16),
                            _buildMapsPanel(dashboardView),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildStatusOverviewCard(dashboardView),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: _buildProgressCard(dashboardView),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildMapsPanel(
                            dashboardView,
                            mapHeight: 360,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCriticalQueueTable(filteredQueue),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Resumen ejecutivo PDF (solo admin) ───────────────────────────────────

  bool _exportingPdf = false;

  // ── Expediente General (solo admin@sao.mx) ─────────────────────────────────

  bool _exportingExpediente = false;

  // Calcula la fecha de inicio según el rango del dashboard
  DateTime _dashboardRangeStart(DashboardRange range) {
    final now = DateTime.now();
    switch (range) {
      case DashboardRange.today:
        return DateTime(now.year, now.month, now.day);
      case DashboardRange.week:
        final weekday = now.weekday;
        final start = now.subtract(Duration(days: weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case DashboardRange.month:
        return DateTime(now.year, now.month, 1);
      case DashboardRange.all:
        return DateTime(2020, 1, 1);
    }
  }

  Future<void> _exportDashboardSummaryPdf(
      DashboardData data, String projectId,
      {DateTime? customDateFrom, DateTime? customDateTo}) async {
    if (_exportingPdf) return;
    if (!mounted) return;
    setState(() => _exportingPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dateFrom = customDateFrom ?? _dashboardRangeStart(data.range);
      final dateTo   = customDateTo   ?? DateTime.now();

      // Cargar actividades aprobadas para el cuerpo del reporte
      final activities = await loadApprovedActivitiesForPdf(
        projectId: projectId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: 200,
      );
      // KPIs: cargar TODAS las actividades del proyecto (paginadas) y filtrar
      // por el mismo campo de fecha que usa el cuerpo del PDF (created_at).
      DashboardActivityMetrics? kpiMetrics;
      try {
        const _kpiApiClient = BackendApiClient();
        final allRawItems = <Map<String, dynamic>>[];
        int kpiPage = 1;
        bool kpiHasNext = true;
        while (kpiHasNext && kpiPage <= 10) {
          final kpiResult = await _kpiApiClient.getJson(
            '/api/v1/activities?project_id=${Uri.encodeQueryComponent(projectId)}&page_size=100&page=$kpiPage',
          );
          if (kpiResult is Map<String, dynamic>) {
            final pageItems = (kpiResult['items'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            allRawItems.addAll(pageItems);
            kpiHasNext = kpiResult['has_next'] == true;
          } else {
            kpiHasNext = false;
          }
          kpiPage++;
        }

        // Filtrar por rango de fechas usando los mismos campos que el cuerpo del PDF:
        //   created_at ?? completed_at ?? reviewed_at ?? last_reviewed_at
        final dfFrom = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
        final dfTo   = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999);
        DateTime? _tryParseKpiDate(String? raw) {
          if (raw == null || raw.isEmpty) return null;
          try { return DateTime.parse(raw); } catch (_) { return null; }
        }
        final filteredRaw = allRawItems.where((item) {
          final rawDate = (item['created_at']        ??
                           item['completed_at']      ??
                           item['reviewed_at']       ??
                           item['last_reviewed_at']  ?? '')?.toString() ?? '';
          final dt = _tryParseKpiDate(rawDate);
          if (dt == null) return true; // sin fecha → incluir
          return !dt.isBefore(dfFrom) && !dt.isAfter(dfTo);
        }).toList();

        kpiMetrics = summarizeDashboardActivityMetrics(filteredRaw);
      } catch (e) {
        debugPrint('[PDF-KPI] Error cargando actividades para KPI: $e');
      }

      // Buscar reportes PDF locales ya descargados para cada actividad
      final localPdfPaths = <String, String>{};
      for (final act in activities) {
        final path = await findExistingLocalReportPath(
          activityId: act.id,
          projectId: act.projectId ?? projectId,
          front: act.frontName,
          state: act.state ?? '',
          municipality: act.municipality ?? '',
          activityType: act.activityType,
        );
        if (path != null) localPdfPaths[act.id] = path;
      }

      // Para actividades con reporte pero sin PDF local, descargar desde la nube
      const apiClient = BackendApiClient();
      for (final act in activities) {
        if (localPdfPaths.containsKey(act.id)) continue;
        if (!act.hasReport) continue;
        debugPrint('[PDF-DL] Descargando reporte para ${act.id} (${act.activityType})');
        try {
          final decoded = await apiClient.getJson(
              '/api/v1/completed-activities/${Uri.encodeComponent(act.id)}');
          if (decoded is! Map<String, dynamic>) continue;
          final detail = CompletedActivityDetail.fromJson(decoded);
          final pdfEvidence = _selectPdfEvidenceForDownload(detail);
          if (pdfEvidence == null) {
            debugPrint('[PDF-DL] Sin evidencia PDF para ${act.id}');
            continue;
          }
          final file = await _downloadPdfFromCloud(detail, pdfEvidence);
          localPdfPaths[act.id] = file.path;
          debugPrint('[PDF-DL] OK: ${file.path}');
        } catch (e) {
          debugPrint('[PDF-DL] ERROR ${act.id}: $e');
        }
      }

      final bytes = await _buildDashboardSummaryPdfBytes(
          data, projectId, activities, dateFrom, dateTo,
          kpiMetrics: kpiMetrics,
          localPdfPaths: localPdfPaths);

      final now = DateTime.now();
      final stamp =
          DateFormat('yyyyMMdd_HHmmss').format(now);
      final project = projectId.trim().isEmpty ? 'GENERAL' : projectId.trim();
      final fileName =
          'resumen_dashboard_${project}_$stamp.pdf';

      final docsRoot = await _resolveDashboardDocumentsRootPath();
      final dir = Directory('$docsRoot/SAO_Reportes');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      await _openDashboardLocalPath(file.path);
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF guardado: ${file.path}'),
          duration: const Duration(seconds: 12),
          action: SnackBarAction(
            label: 'Abrir carpeta',
            onPressed: () => _openDashboardLocalPath(dir.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  // ── Diálogo de selección de proyectos para exportar PDF ────────────────

  Future<void> _showPdfProjectSelectionDialog(
    DashboardData data,
    String currentProjectId,
    List<String> projectOptions,
  ) async {
    if (_exportingPdf) return;
    if (!mounted) return;

    final available = projectOptions.where((p) => p.isNotEmpty).toList()..sort();
    // Pre-seleccionar el proyecto activo
    final selected = <String>{
      if (currentProjectId.isNotEmpty && available.contains(currentProjectId))
        currentProjectId,
    };

    // Rango de fechas por defecto: igual al rango activo del dashboard
    var pickedFrom = _dashboardRangeStart(data.range);
    var pickedTo   = DateTime.now();

    final confirmed = await showDialog<(Set<String>, DateTime, DateTime)>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          final allSelected = selected.length == available.length;
          return AlertDialog(
            title: const Text('Exportar PDF'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Rango de fechas ────────────────────────────────────────────
                  const Text('Rango de fechas:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerButton(
                          label: 'Desde',
                          date: pickedFrom,
                          firstDate: DateTime(2020),
                          lastDate: pickedTo,
                          onPicked: (d) => setDlgState(() => pickedFrom = d),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DatePickerButton(
                          label: 'Hasta',
                          date: pickedTo,
                          firstDate: pickedFrom,
                          lastDate: DateTime.now(),
                          onPicked: (d) => setDlgState(() => pickedTo = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ─ Proyectos ───────────────────────────────────────────────────
                  const Text(
                    'Proyectos a incluir:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    title: Text(
                      allSelected ? 'Deseleccionar todos' : 'Seleccionar todos',
                      style: const TextStyle(fontSize: 13),
                    ),
                    value: allSelected,
                    tristate: true,
                    onChanged: (_) {
                      setDlgState(() {
                        if (allSelected) selected.clear();
                        else selected.addAll(available);
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 8),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay proyectos disponibles.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Column(
                          children: available.map((pid) {
                            return CheckboxListTile(
                              title: Text(pid, style: const TextStyle(fontSize: 13)),
                              value: selected.contains(pid),
                              onChanged: (checked) {
                                setDlgState(() {
                                  if (checked == true) selected.add(pid);
                                  else selected.remove(pid);
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, (Set<String>.from(selected), pickedFrom, pickedTo)),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text(
                  selected.isEmpty ? 'Exportar' : 'Exportar (${selected.length})',
                ),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == null || confirmed.$1.isEmpty) return;

    final (projects, dateFrom, dateTo) = confirmed;
    final sorted = projects.toList()..sort();
    for (final pid in sorted) {
      await _exportDashboardSummaryPdf(data, pid,
          customDateFrom: dateFrom,
          customDateTo: DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59));
    }
  }

  // ── Catálogo de nombres por código de tipo de actividad ──────────────────
  static const Map<String, String> _activityTypeNames = {
    'CAM'    : 'Caminamiento',
    'REU'    : 'Reunión',
    'ASP'    : 'Asamblea Protocolizada',
    'CIN'    : 'Consulta Indígena',
    'SOC'    : 'Socialización',
    'AIN'    : 'Acompañamiento Institucional',
    'CAM_DDV': 'Verificación de DDV',
    'CAM_MAR': 'Marcaje de afectaciones',
    'CAM_ACC': 'Revisión de accesos / BDT',
    'CAM_SEG': 'Seguimiento técnico',
    'REU_TEC': 'Reunión Técnica / Interinstitucional',
    'REU_EJI': 'Reunión Ejidal / Comisariado',
    'REU_MUN': 'Reunión Municipal / Estatal',
    'REU_SEG': 'Reunión de Seguimiento',
    'REU_INF': 'Reunión Informativa',
    'REU_MES': 'Mesa Técnica',
  };

  String _resolveActivityTypeName(String code) {
    final c = code.trim().toUpperCase();
    if (_activityTypeNames.containsKey(c)) return _activityTypeNames[c]!;
    // Si el código ya es descriptivo (tiene espacios o >5 chars) úsalo tal cual
    if (code.contains(' ') || code.length > 5) return code.trim();
    return code.trim();
  }

  Future<Uint8List> _buildDashboardSummaryPdfBytes(
      DashboardData data,
      String projectId,
      List<ReportActivityItem> activities,
      DateTime dateFrom,
      DateTime dateTo,
      {DashboardActivityMetrics? kpiMetrics,
      Map<String, String> localPdfPaths = const {}}) async {
    // ── Fuentes Unicode ──────────────────────────────────────────────────
    final baseFont = await _loadSystemPdfFont(
            '/System/Library/Fonts/Supplemental/Arial.ttf') ??
        await _loadSystemPdfFont('/Library/Fonts/Arial.ttf');
    final boldFont = await _loadSystemPdfFont(
            '/System/Library/Fonts/Supplemental/Arial Bold.ttf') ??
        await _loadSystemPdfFont('/Library/Fonts/Arial Bold.ttf');

    // ── Rasterizar PDFs locales para incrustar ────────────────────────────
    // Limitado a primera página (portada) a 96 DPI para evitar OOM.
    // Se procesan hasta 200 PDFs por exportación para cubrir proyectos grandes.
    const _kMaxRasterized = 200;
    final Map<String, List<pw.MemoryImage>> rasterizedPages = {};
    for (final entry in localPdfPaths.entries) {
      if (rasterizedPages.length >= _kMaxRasterized) break;
      try {
        final pdfBytes = await File(entry.value).readAsBytes();
        final pages = <pw.MemoryImage>[];
        await for (final raster in Printing.raster(pdfBytes, dpi: 96, pages: [0])) {
          pages.add(pw.MemoryImage(await raster.toPng()));
          break; // Solo primera página
        }
        if (pages.isNotEmpty) rasterizedPages[entry.key] = pages;
      } catch (_) {}
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont ?? pw.Font.helvetica(),
        bold: boldFont ?? pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );

    // ── Colores ────────────────────────────────────────────────────────
    const headerBg     = PdfColor.fromInt(0xFF0F172A);
    const sectionBg    = PdfColor.fromInt(0xFF1E3A5F);
    const accentBlue   = PdfColor.fromInt(0xFF3B82F6);
    const accentGreen  = PdfColor.fromInt(0xFF10B981);
    const accentOrange = PdfColor.fromInt(0xFFF59E0B);
    const accentRed    = PdfColor.fromInt(0xFFEF4444);
    const accentPurple = PdfColor.fromInt(0xFF7C3AED);
    const textDark     = PdfColor.fromInt(0xFF1F2937);
    const textGray     = PdfColor.fromInt(0xFF6B7280);
    const borderGray   = PdfColor.fromInt(0xFFE5E7EB);
    const stripeBg     = PdfColor.fromInt(0xFFF1F5F9);

    // ── Datos derivados ────────────────────────────────────────────────
    final now              = DateTime.now();
    final dateStr          = DateFormat('dd/MM/yyyy HH:mm', 'es').format(now);
    final fmtD            = DateFormat('dd/MM/yyyy', 'es');
    final rangeStr         = '${fmtD.format(dateFrom)} – ${fmtD.format(dateTo)}';
    // Etiqueta basada en las fechas reales del reporte exportado
    final rangeLabel = 'Reporte del periodo  –  $rangeStr';
    final rangeHeader = rangeStr;
    final project          = projectId.trim().isEmpty ? 'GENERAL' : projectId.trim();
    final fronteLabel      = project.toUpperCase() == 'TSNL' ? 'Segmento' : 'Frente';

    // KPIs calculados desde el universo completo de actividades del periodo
    // kpiMetrics viene del endpoint assignments (todos los estados, no solo aprobados)
    // Si no hay datos del endpoint assignments, fallback a actividades aprobadas
    final _rApproved  = kpiMetrics?.approved ?? activities.where((a) => a.isApprovedForReport).length;
    final _rRejected  = kpiMetrics?.rejected ?? activities.where((a) {
      final rs = (a.reviewStatus ?? '').trim().toUpperCase();
      return rs == 'REJECTED' || a.status.trim().toUpperCase() == 'RECHAZADO';
    }).length;
    final _rNeedsFix  = kpiMetrics?.needsFix ?? activities.where((a) =>
        (a.reviewStatus ?? '').trim().toUpperCase() == 'CHANGES_REQUIRED').length;
    final _rTotal     = kpiMetrics?.total ?? activities.length;
    final _rPending   = kpiMetrics?.pending ?? (_rTotal - _rApproved - _rRejected - _rNeedsFix).clamp(0, _rTotal);
    final progressPct      = _rTotal == 0 ? 0 : (_rApproved / _rTotal * 100).round();
    final progressFraction = _rTotal == 0 ? 0.0 : (_rApproved / _rTotal).clamp(0.0, 1.0);

    // Agrupar actividades por nombre de tipo
    final byType = <String, List<ReportActivityItem>>{};
    for (final act in activities) {
      byType.putIfAbsent(_resolveActivityTypeName(act.activityType), () => []).add(act);
    }
    final sortedTypes = byType.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // ── Mapa interactivo: URL del servicio SAO ──────────────────
    const heatmapUrl = 'https://sao-api-97150883570.us-central1.run.app/map';

    const tileCols = 3;
    const tileRows = 3;

    // Derivar geopoints de las actividades cargadas para este reporte y proyecto.
    // Esto garantiza que el mapa haga zoom al área real del periodo seleccionado.
    final _actGpts = activities
        .where((a) => a.technicalLatitude != null && a.technicalLongitude != null)
        .map((a) {
          final lat = double.tryParse(a.technicalLatitude!) ?? 0.0;
          final lon = double.tryParse(a.technicalLongitude!) ?? 0.0;
          return (lat: lat, lon: lon, risk: a.riskLevel ?? '');
        })
        .where((p) => p.lat != 0.0 && p.lon != 0.0)
        .toList();
    // Fallback a los geopoints del dashboard si las actividades no tienen GPS
    final gpts = _actGpts.isNotEmpty
        ? _actGpts
        : data.geoPoints
            .where((p) => p.lat != 0 && p.lon != 0)
            .map((p) => (lat: p.lat, lon: p.lon, risk: p.risk))
            .toList();
    final Map<String, pw.MemoryImage> tileImages = {};
    var gridLonMin = 0.0, gridLonMax = 1.0;
    var gridLatMin = 0.0, gridLatMax = 1.0;
    var tileZoom = 7, tileX0 = 0, tileY0 = 0;

    if (gpts.isNotEmpty) {
      final rawLonMin = gpts.map((p) => p.lon).reduce(math.min);
      final rawLonMax = gpts.map((p) => p.lon).reduce(math.max);
      final rawLatMin = gpts.map((p) => p.lat).reduce(math.min);
      final rawLatMax = gpts.map((p) => p.lat).reduce(math.max);
      final lonSpan = math.max(rawLonMax - rawLonMin, 0.05);
      final latSpan = math.max(rawLatMax - rawLatMin, 0.05);
      final bLonMin = rawLonMin - lonSpan * 0.2;
      final bLonMax = rawLonMax + lonSpan * 0.2;
      final bLatMin = rawLatMin - latSpan * 0.2;
      final bLatMax = rawLatMax + latSpan * 0.2;

      // Use median instead of mean to resist outlier pull
      final sortedLats = (gpts.map((p) => p.lat).toList()..sort());
      final sortedLons = (gpts.map((p) => p.lon).toList()..sort());
      final cLat = sortedLats[sortedLats.length ~/ 2];
      final cLon = sortedLons[sortedLons.length ~/ 2];

      int lonToX(double lon, int z) =>
          ((lon + 180) / 360 * (1 << z)).floor().clamp(0, (1 << z) - 1);
      int latToY(double lat, int z) {
        final lr = lat * math.pi / 180;
        return ((1.0 - math.log(math.tan(lr) + 1.0 / math.cos(lr)) / math.pi)
                / 2.0 * (1 << z))
            .floor()
            .clamp(0, (1 << z) - 1);
      }
      double xToLon(int x, int z) => x / (1 << z) * 360.0 - 180.0;
      double yToLat(int y, int z) {
        final n = math.pi * (1.0 - 2.0 * y / (1 << z));
        return 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
      }

      // Find tightest zoom where bbox fits within _tileCols × _tileRows grid
      for (int z = 12; z >= 5; z--) {
        final x0 = lonToX(bLonMin, z);
        final x1 = lonToX(bLonMax, z);
        final y0 = latToY(bLatMax, z);
        final y1 = latToY(bLatMin, z);
        if ((x1 - x0 + 1) <= tileCols && (y1 - y0 + 1) <= tileRows) {
          tileZoom = z;
          // Center grid on median point
          final cx = lonToX(cLon, z);
          final cy = latToY(cLat, z);
          tileX0 = (cx - tileCols ~/ 2).clamp(0, (1 << z) - tileCols);
          tileY0 = (cy - tileRows ~/ 2).clamp(0, (1 << z) - tileRows);
          break;
        }
      }

      gridLonMin = xToLon(tileX0, tileZoom);
      gridLonMax = xToLon(tileX0 + tileCols, tileZoom);
      gridLatMax = yToLat(tileY0, tileZoom);
      gridLatMin = yToLat(tileY0 + tileRows, tileZoom);

      // Fetch all _tileCols × _tileRows tiles concurrently
      final tileFutures = <Future<void>>[];
      for (int r = 0; r < tileRows; r++) {
        for (int c = 0; c < tileCols; c++) {
          final lr = r, lc = c;
          tileFutures.add(() async {
            try {
              final resp = await http
                  .get(
                    Uri.parse(
                        'https://tile.openstreetmap.org/$tileZoom/${tileX0 + lc}/${tileY0 + lr}.png'),
                    headers: {'User-Agent': 'SAO-Desktop/2.0 (reporting)'},
                  )
                  .timeout(const Duration(seconds: 10));
              if (resp.statusCode == 200) {
                tileImages['$lr,$lc'] = pw.MemoryImage(resp.bodyBytes);
              }
            } catch (_) {}
          }());
        }
      }
      await Future.wait(tileFutures);
    }

    // ── Helpers locales ────────────────────────────────────────────────
    String fmtDate(String raw) {
      try { return DateFormat('dd/MM/yyyy', 'es').format(DateTime.parse(raw)); }
      catch (_) { return raw.length >= 10 ? raw.substring(0, 10) : raw; }
    }

    // Sanitiza el nombre del responsable: convierte emails a nombre legible.
    // p.ej. "juan.perez@gmail.com" → "Juan Pérez" (parte local formateada).
    String sanitizeName(String? raw) {
      final s = raw?.trim() ?? '';
      if (s.isEmpty) return '';
      if (!s.contains('@')) return s;
      // Tomar la parte local del email, reemplazar puntos/guiones por espacio
      final local = s.split('@').first
          .replaceAll('.', ' ')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
      // Capitalizar cada palabra
      return local.split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
          .join(' ');
    }

    pw.Widget sectionTitle(String title, {PdfColor? bg}) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: bg ?? sectionBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 11,
          fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );

    pw.Widget kpiCard(String label, String value, PdfColor color) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: borderGray),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 20,
              fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: textGray)),
        ]),
      ),
    );

    // ── Documento ──────────────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
      header: (_) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: borderGray))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SAO – Informe Ejecutivo de Proyecto',
                style: const pw.TextStyle(fontSize: 8, color: textGray)),
            pw.Text('$project  |  $rangeHeader',
                style: const pw.TextStyle(fontSize: 8, color: textGray)),
          ],
        ),
      ),
      footer: (_) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderGray))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generado: $dateStr',
                style: const pw.TextStyle(fontSize: 7, color: textGray)),
            pw.Text('Documento confidencial – uso interno',
                style: const pw.TextStyle(fontSize: 7, color: textGray)),
          ],
        ),
      ),
      build: (context) {
        final w = <pw.Widget>[];

        // ─── 1. Portada / encabezado ejecutivo ────────────────────────
        w.add(pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          decoration: const pw.BoxDecoration(
            color: headerBg,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('INFORME EJECUTIVO DE PROYECTO',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold,
                    color: accentBlue, letterSpacing: 1.5)),
            pw.SizedBox(height: 6),
            pw.Text(project,
                style: pw.TextStyle(fontSize: 22,
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(rangeLabel,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
            pw.SizedBox(height: 16),
            // Barra de progreso
            pw.Row(children: [
              pw.Text('Avance general del proyecto',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
              pw.Spacer(),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('$progressPct%', style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold,
                    color: progressPct >= 70 ? accentGreen
                        : progressPct >= 40 ? accentOrange : accentRed)),
                pw.Text('$_rApproved aprobadas / $_rTotal total',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
              ]),
            ]),
            pw.SizedBox(height: 8),
            pw.Stack(children: [
              pw.Container(height: 10, width: double.infinity,
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF4B5568),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)))),
              pw.Container(height: 10, width: 490 * progressFraction,
                  decoration: pw.BoxDecoration(
                      color: progressPct >= 70 ? accentGreen
                          : progressPct >= 40 ? accentOrange : accentRed,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)))),
            ]),
          ]),
        ));
        w.add(pw.SizedBox(height: 14));

        // ─── 2. KPIs de estado ────────────────────────────────────────
        w.add(pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          kpiCard('Actividades en el periodo', '$_rTotal', accentBlue),
          kpiCard('Aprobadas', '$_rApproved', accentGreen),
          kpiCard('Pendientes revisión', '$_rPending', accentOrange),
          kpiCard('Rechazadas', '$_rRejected', accentRed),
          pw.Expanded(child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: pw.BoxDecoration(color: PdfColors.white,
              border: pw.Border.all(color: borderGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('$_rNeedsFix', style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: accentRed)),
              pw.SizedBox(height: 2),
              pw.Text('Necesita corrección',
                  style: const pw.TextStyle(fontSize: 8, color: textGray)),
            ]),
          )),
        ]));
        w.add(pw.SizedBox(height: 18));

        // ─── 3. ¿Qué se realizó en el periodo? ───────────────────────
        if (sortedTypes.isNotEmpty) {
          w.add(sectionTitle('¿Qué se realizó en el periodo?'));
          w.add(pw.SizedBox(height: 10));

          // Gráfico de barras horizontal por tipo de actividad
          {
            final maxCount = sortedTypes.first.value.length;
            const barTrackW = 260.0;
            const barH = 12.0;
            const barPalette = [
              accentBlue,
              accentGreen,
              accentOrange,
              accentPurple,
              accentRed,
              PdfColor.fromInt(0xFF0891B2),
              PdfColor.fromInt(0xFF059669),
            ];
            final barRows = sortedTypes.asMap().entries.map((e) {
              final count = e.value.value.length;
              final fillW = (count / maxCount) * barTrackW;
              final barColor = barPalette[e.key % barPalette.length];
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(
                      width: 136,
                      child: pw.Text(e.value.key,
                          style: pw.TextStyle(fontSize: 8,
                              fontWeight: pw.FontWeight.bold, color: textDark),
                          maxLines: 2),
                    ),
                    pw.Stack(children: [
                      pw.Container(
                        width: barTrackW, height: barH,
                        decoration: const pw.BoxDecoration(
                          color: borderGray,
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                      ),
                      pw.Container(
                        width: fillW.clamp(6.0, barTrackW), height: barH,
                        decoration: pw.BoxDecoration(
                          color: barColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                      ),
                    ]),
                    pw.SizedBox(width: 8),
                    pw.Text('$count',
                        style: pw.TextStyle(fontSize: 9,
                            fontWeight: pw.FontWeight.bold, color: textDark)),
                  ],
                ),
              );
            }).toList();
            w.add(pw.Column(children: barRows));
          }
        }

        // ─── 4. Mapa de calor ──────────────────────────────────────────
        w.add(pw.SizedBox(height: 18));
        w.add(sectionTitle('Distribución geográfica de actividades'));
        w.add(pw.SizedBox(height: 10));

        if (gpts.isNotEmpty) {
          const mapW = 521.0;
          const mapH = 220.0;
          const tileDrawW = mapW / tileCols;
          const tileDrawH = mapH / tileRows;
          final lonRange = (gridLonMax - gridLonMin).abs().clamp(0.01, 180.0);
          final latRange = (gridLatMax - gridLatMin).abs().clamp(0.01, 90.0);

          PdfColor riskColor(String risk) => switch (risk.toLowerCase()) {
            'alto'  => accentRed,
            'medio' => accentOrange,
            _       => accentGreen,
          };

          w.add(pw.SizedBox(
            width: mapW,
            height: mapH,
            child: pw.Stack(children: [
              // Fondo de respaldo
              pw.Container(
                width: mapW, height: mapH,
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFEFF6FF),
                  border: pw.Border.all(color: borderGray),
                ),
              ),
              // Tiles OSM — always full _tileCols × _tileRows grid
              for (int r = 0; r < tileRows; r++)
                for (int c = 0; c < tileCols; c++)
                  if (tileImages.containsKey('$r,$c'))
                    pw.Positioned(
                      left: c * tileDrawW,
                      top: r * tileDrawH,
                      child: pw.Image(
                        tileImages['$r,$c']!,
                        width: tileDrawW + 1,
                        height: tileDrawH + 1,
                        fit: pw.BoxFit.fill,
                      ),
                    ),
              // Puntos georeferenciados
              ...gpts.map((p) {
                final x = ((p.lon - gridLonMin) / lonRange * mapW).clamp(4.0, mapW - 14.0);
                final y = ((gridLatMax - p.lat) / latRange * mapH).clamp(4.0, mapH - 14.0);
                return pw.Positioned(
                  left: x - 5,
                  top: y - 5,
                  child: pw.Container(
                    width: 12, height: 12,
                    decoration: pw.BoxDecoration(
                      color: riskColor(p.risk),
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColors.white, width: 1.5),
                    ),
                  ),
                );
              }),
            ]),
          ));
          // Leyenda
          w.add(pw.SizedBox(height: 6));
          w.add(pw.Row(children: [
            for (final e in [('Alto', accentRed), ('Medio', accentOrange), ('Bajo', accentGreen)])
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 14),
                child: pw.Row(children: [
                  pw.Container(width: 8, height: 8,
                      decoration: pw.BoxDecoration(color: e.$2, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 4),
                  pw.Text(e.$1, style: const pw.TextStyle(fontSize: 7, color: textGray)),
                ]),
              ),
          ]));
          w.add(pw.SizedBox(height: 10));
        }

        // Botón link al mapa de calor interactivo
        w.add(pw.UrlLink(
          destination: heatmapUrl,
          child: pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: headerBg,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Ver mapa interactivo de actividades',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.Text(heatmapUrl,
                    style: const pw.TextStyle(
                        fontSize: 7,
                        color: accentBlue,
                        decoration: pw.TextDecoration.underline)),
              ],
            ),
          ),
        ));

        return w;
      },
    ));

    // ── Tabla de actividades en landscape ──────────────────────────────
    if (activities.isNotEmpty) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 5),
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderGray))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('SAO – Detalle de actividades realizadas',
                  style: const pw.TextStyle(fontSize: 8, color: textGray)),
              pw.Text('$project  |  $rangeHeader',
                  style: const pw.TextStyle(fontSize: 8, color: textGray)),
            ],
          ),
        ),
        footer: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 5),
          padding: const pw.EdgeInsets.only(top: 5),
          decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderGray))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generado: $dateStr',
                  style: const pw.TextStyle(fontSize: 7, color: textGray)),
              pw.Text('Documento confidencial – uso interno',
                  style: const pw.TextStyle(fontSize: 7, color: textGray)),
            ],
          ),
        ),
        build: (context) {
          return [
            pw.Anchor(
              name: '_index_',
              child: pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0),  // Fecha
                  1: const pw.FlexColumnWidth(1.5),  // Tipo
                  2: const pw.FlexColumnWidth(1.8),  // Subtipo
                  3: const pw.FlexColumnWidth(2.0),  // Temas
                  4: const pw.FlexColumnWidth(1.2),  // Frente
                  5: const pw.FlexColumnWidth(1.5),  // Municipio
                  6: const pw.FlexColumnWidth(1.8),  // Responsable
                  7: const pw.FlexColumnWidth(0.7),  // Riesgo
                  8: const pw.FlexColumnWidth(3.5),  // Desarrollo
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBg),
                    children: [
                      for (final h in [
                        'Fecha', 'Tipo de actividad', 'Subtipo', 'Temas',
                        fronteLabel, 'Municipio', 'Responsable', 'Riesgo', 'Desarrollo',
                      ])
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 7,
                              fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    ],
                  ),
                  ...activities.take(200).toList().asMap().entries.map((entry) {
                    final i = entry.key; final act = entry.value;
                    final hasEmbed = rasterizedPages.containsKey(act.id);
                    final anchor = 'report_${act.id}';
                    final topicsText = act.topics
                        .where((t) {
                          final tl = t.trim().toLowerCase();
                          return tl.isNotEmpty && tl != 'custom' && tl != 'otro' && !t.trim().toUpperCase().startsWith('CUSTOM_');
                        })
                        .join(', ');
                    final rawDetail = act.notes?.trim().isNotEmpty == true
                        ? act.notes!.trim()
                        : (act.detail?.trim().isNotEmpty == true
                            ? act.detail!.trim()
                            : buildReportNaturalNarrative(act));
                    final detailText = rawDetail.length > 220
                        ? '${rawDetail.substring(0, 220)}…'
                        : rawDetail;

                    pw.Widget cell(pw.Widget child) {
                      if (!hasEmbed) return child;
                      return pw.Link(destination: anchor, child: child);
                    }

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                          color: i % 2 == 0 ? PdfColors.white : stripeBg),
                      children: [
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(fmtDate(act.createdAt),
                                style: pw.TextStyle(fontSize: 7,
                                    color: hasEmbed ? accentBlue : textDark,
                                    decoration: hasEmbed ? pw.TextDecoration.underline : null)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(_resolveActivityTypeName(act.activityType),
                                style: const pw.TextStyle(fontSize: 7, color: textDark)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(() {
                              final s = act.subcategory?.trim() ?? '';
                              final sl = s.toLowerCase();
                              return (sl == 'custom' || sl == 'otro' || s.toUpperCase().startsWith('CUSTOM_')) ? '' : s;
                            }(),
                                style: const pw.TextStyle(fontSize: 7, color: textGray)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(topicsText,
                                style: const pw.TextStyle(fontSize: 7, color: textGray)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                project.toUpperCase() == 'TSNL'
                                    ? act.frontName.replaceAllMapped(RegExp(r'\bF(\d+)'), (m) => 'S${m[1]}')
                                    : act.frontName,
                                style: const pw.TextStyle(fontSize: 7, color: textDark)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(act.municipality ?? '',
                                style: const pw.TextStyle(fontSize: 7, color: textDark)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(sanitizeName(act.assignedName),
                                style: const pw.TextStyle(fontSize: 7, color: textDark)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(act.riskLevel ?? '',
                                style: const pw.TextStyle(fontSize: 7, color: textGray)))),
                        cell(pw.Padding(padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(detailText,
                                style: const pw.TextStyle(fontSize: 7, color: textDark)))),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ];
        },
      ));
    } // end if (activities.isNotEmpty)

    // ── Páginas incrustadas: un bloque por cada PDF de actividad ─────────
    for (final act in activities) {
      final pages = rasterizedPages[act.id];
      if (pages == null || pages.isEmpty) continue;
      final typeName = _resolveActivityTypeName(act.activityType);

      // Primera página: encabezado + anchor + imagen
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
        build: (context) => pw.Anchor(
          name: 'report_${act.id}',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Mini encabezado de sección
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const pw.BoxDecoration(
                  color: sectionBg,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '$typeName  ·  ${act.frontName}  ·  ${act.municipality ?? ''}'
                            '  |  ${fmtDate(act.createdAt)}',
                        style: pw.TextStyle(
                            fontSize: 8, fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Link(
                      destination: '_index_',
                      child: pw.Text('↑ Volver al índice',
                          style: const pw.TextStyle(
                              fontSize: 7, color: accentBlue,
                              decoration: pw.TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Expanded(
                child: pw.Image(pages[0], fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ),
      ));

      // Páginas adicionales del mismo PDF
      for (int p = 1; p < pages.length; p++) {
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(24, 18, 24, 18),
          build: (context) => pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const pw.BoxDecoration(color: headerBg),
                child: pw.Text(
                  '$typeName  ·  ${act.frontName}  –  pág. ${p + 1}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey300),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Expanded(
                child: pw.Image(pages[p], fit: pw.BoxFit.contain),
              ),
            ],
          ),
        ));
      }
    }

    return pdf.save();
  }

  Widget _buildHeader(
    DashboardData data,
    DashboardRange range,
    String selectedProjectId,
    List<String> projectOptions,
    List<String> userOptions,
  ) {
    final activeFronts = data.frontProgress
        .where((item) => item.front.trim().isNotEmpty)
        .length;
    final progressPct = (data.avancePct * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard de avance operativo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seguimiento de proyectos, frentes, revisión y focos operativos del periodo seleccionado.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _buildProjectSelector(selectedProjectId, projectOptions),
              const SizedBox(width: 8),
              _buildUserSelector(userOptions),
              const SizedBox(width: 8),
              _buildRangeSelector(range),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                tooltip: 'Actualizar',
              ),
              if (ref.watch(currentAppUserProvider)?.isAdmin == true) ...
                [
                  Tooltip(
                    message: 'Exportar resumen ejecutivo (solo admin)',
                    child: IconButton(
                      onPressed: () => _showPdfProjectSelectionDialog(data, selectedProjectId, projectOptions),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                    ),
                  ),
                ],
              if ((ref.watch(currentAppUserProvider)?.email ?? '').toLowerCase() == 'admin@sao.mx') ...
                [
                  Tooltip(
                    message: 'Descargar expediente general (solo admin@sao.mx)',
                    child: IconButton(
                      onPressed: _exportingExpediente
                          ? null
                          : () => _showBulkExpedienteDialog(projectOptions),
                      icon: _exportingExpediente
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_zip_rounded, color: Colors.white),
                    ),
                  ),
                ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _chipStat('Actividades', '${data.totalInQueue}'),
              _chipStat('Frentes activos', '$activeFronts'),
              _chipStat('Avance global', '$progressPct%'),
              _chipStat('Pendientes', '${data.pendingCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSelector(String selectedProjectId, List<String> projectOptions) {
    final selectedValue = projectOptions.contains(selectedProjectId) ? selectedProjectId : '';
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: SaoColors.gray800,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value == null) return;
            ref.read(activeProjectIdProvider.notifier).select(value);
          },
          items: [
            const DropdownMenuItem(value: '', child: Text('Todos')),
            ...projectOptions.map(
              (projectId) => DropdownMenuItem(value: projectId, child: Text(projectId)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelector(List<String> userOptions) {
    final selectedValue = userOptions.contains(_planningUserFilter) ? _planningUserFilter : 'Todo';
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: SaoColors.gray800,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _planningUserFilter = value);
          },
          items: userOptions
              .map((value) => DropdownMenuItem(value: value, child: Text(value, overflow: TextOverflow.ellipsis)))
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _chipStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector(DashboardRange range) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<DashboardRange>(
          value: range,
          dropdownColor: SaoColors.gray800,
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value == null) return;
            ref.read(selectedDashboardRangeProvider.notifier).state = value;
          },
          items: const [
            DropdownMenuItem(value: DashboardRange.today, child: Text('Hoy')),
            DropdownMenuItem(value: DashboardRange.week, child: Text('Semana')),
            DropdownMenuItem(value: DashboardRange.month, child: Text('Mes')),
            DropdownMenuItem(value: DashboardRange.all, child: Text('Todo')),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardFiltersCard(DashboardData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Búsqueda y filtros',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Escribe un frente, estado o municipio y presiona Enter para agregar una etiqueta de filtro.',
            style: TextStyle(fontSize: 12, color: SaoColors.textMutedFor(context)),
          ),
          const SizedBox(height: 12),
          _buildCompactMapFilters(data),
        ],
      ),
    );
  }

  Widget _buildKpis(BuildContext context, DashboardData data) {
    final activeFronts = data.frontProgress.where((item) => item.front.trim().isNotEmpty).length;
    final highRiskCount = (data.riskCounts['alto'] ?? 0) + (data.riskCounts['prioritario'] ?? 0);
    final progressPct = (data.avancePct * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 900
            ? 2
            : constraints.maxWidth < 1400
                ? 3
                : 6;
        return GridView.count(
          crossAxisCount: count,
          childAspectRatio: constraints.maxWidth < 1400 ? 2.35 : 2.0,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _kpiCard(
              title: 'Actividades del periodo',
              value: data.totalInQueue,
              subtitle: '$activeFronts frentes con actividad',
              trend: data.pendingTrend,
              color: SaoColors.primary,
              icon: Icons.assignment_turned_in_rounded,
              filter: DashboardKpiFilter.all,
            ),
            _kpiCard(
              title: 'Aprobadas',
              value: data.approvedCount,
              subtitle: _trendSubtitle(data.approvedTrend),
              trend: data.approvedTrend,
              color: SaoColors.success,
              icon: Icons.check_circle_rounded,
              filter: DashboardKpiFilter.approved,
            ),
            _kpiCard(
              title: 'Pendientes de revisión',
              value: data.pendingCount,
              subtitle: _trendSubtitle(data.pendingTrend),
              trend: data.pendingTrend,
              color: SaoColors.info,
              icon: Icons.pending_actions_rounded,
              filter: DashboardKpiFilter.pending,
            ),
            _kpiCard(
              title: 'Requieren corrección',
              value: data.needsFixCount,
              subtitle: _trendSubtitle(data.needsFixTrend),
              trend: data.needsFixTrend,
              color: SaoColors.warning,
              icon: Icons.edit_note_rounded,
              filter: DashboardKpiFilter.needsFix,
            ),
            _kpiCard(
              title: 'Rechazadas',
              value: data.rejectedCount,
              subtitle: _trendSubtitle(data.rejectedTrend),
              trend: data.rejectedTrend,
              color: SaoColors.error,
              icon: Icons.cancel_rounded,
              filter: DashboardKpiFilter.rejected,
            ),
            _kpiCard(
              title: 'Avance global',
              value: progressPct,
              subtitle: '${data.avgValidationHours.toStringAsFixed(1)} h promedio · $highRiskCount puntos de alto riesgo',
              trend: const DashboardTrend(current: 0, previous: 0),
              color: SaoColors.primaryLight,
              icon: Icons.insights_rounded,
              filter: DashboardKpiFilter.all,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusOverviewCard(DashboardData data) {
    final total = data.totalInQueue <= 0
        ? (data.pendingCount + data.approvedCount + data.rejectedCount + data.needsFixCount)
        : data.totalInQueue;
    final rows = [
      ('Aprobadas', data.approvedCount, SaoColors.success),
      ('Pendientes', data.pendingCount, SaoColors.info),
      ('Corrección', data.needsFixCount, SaoColors.warning),
      ('Rechazadas', data.rejectedCount, SaoColors.error),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen ejecutivo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Distribución del flujo actual para medir avance y rezago.',
            style: TextStyle(fontSize: 12, color: SaoColors.textMutedFor(context)),
          ),
          const SizedBox(height: 14),
          ...rows.map((row) {
            final label = row.$1;
            final value = row.$2;
            final color = row.$3;
            final ratio = total == 0 ? 0.0 : (value / total).clamp(0, 1).toDouble();
            final pct = (ratio * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: SaoColors.gray700),
                        ),
                      ),
                      Text(
                        '$value · $pct%',
                        style: TextStyle(fontWeight: FontWeight.w700, color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    minHeight: 10,
                    value: ratio,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: SaoColors.gray200,
                    color: color,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required int value,
    required String subtitle,
    required DashboardTrend trend,
    required Color color,
    required IconData icon,
    required DashboardKpiFilter filter,
  }) {
    final selected = _kpiFilter == filter;
    final sparkline = _sparklinePoints(trend);
    return InkWell(
      onTap: () => setState(() => _kpiFilter = filter),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SaoColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : SaoColors.borderFor(context),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: SaoColors.gray900.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                SizedBox(
                  width: 56,
                  height: 18,
                  child: CustomPaint(painter: _SparklinePainter(sparkline, color)),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: SaoColors.gray800, fontSize: 12),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: SaoColors.gray500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(DashboardData data) {
    final frontRows = data.frontProgress.map(_frontProgressRow).toList(growable: false);
    final useScroll = frontRows.length > 4;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avance por frente',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparativo entre lo planeado y lo ejecutado para ubicar frentes con mejor o menor desempeño.',
            style: TextStyle(fontSize: 12, color: SaoColors.textMutedFor(context)),
          ),
          const SizedBox(height: 12),
          if (data.frontProgress.isEmpty)
            const _EmptyState(
              icon: Icons.bar_chart_rounded,
              iconColor: SaoColors.gray300,
              message: 'Sin datos para el periodo seleccionado',
            )
          else if (useScroll)
            SizedBox(
              height: 240,
              child: Scrollbar(
                controller: _frontProgressScrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _frontProgressScrollController,
                  children: frontRows,
                ),
              ),
            )
          else
            ...frontRows,
        ],
      ),
    );
  }

  Widget _frontProgressRow(FrontProgressItem item) {
    final ratio = item.planned == 0 ? 0.0 : (item.executed / item.planned).clamp(0, 1).toDouble();
    final pct = (ratio * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.front,
                  style: const TextStyle(fontSize: 12, color: SaoColors.gray700, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${item.executed}/${item.planned}',
                style: const TextStyle(fontSize: 12, color: SaoColors.gray600),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: 12, color: SaoColors.info, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: ratio,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: SaoColors.gray200,
                color: SaoColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsPanel(
    DashboardData data, {
    double mapHeight = 280,
    double minCardHeight = 0,
  }) {
    final planningPoints = _filterPlanningMapPoints(data.geoPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMapCard(
          title: 'Mapa de Calor',
          subtitle: 'Actividades registradas del periodo, con y sin reporte',
          points: planningPoints,
          summary: 'Planeacion · ${planningPoints.length} puntos',
          emptyMessage: 'Sin actividades visibles para esos filtros, incluso sin reporte',
          filtersSection: const SizedBox.shrink(),
          mapHeight: mapHeight,
          minCardHeight: minCardHeight,
        ),
      ],
    );
  }

  Widget _buildMapCard({
    required String title,
    required String subtitle,
    required List<DashboardGeoPoint> points,
    required String summary,
    required String emptyMessage,
    required Widget filtersSection,
    required double mapHeight,
    required double minCardHeight,
  }) {
    final groupedPoints = _groupMapPoints(points);
    final visibleMarkers = _expandMapMarkers(groupedPoints);
    final locationCounts = _locationCountsFor(points);
    final selectedPoint = _resolveSelectedMapPoint(points);

    Widget buildMapView() {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: mapHeight,
          child: points.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: SaoColors.surfaceMutedFor(context),
                    border: Border.all(color: SaoColors.borderFor(context)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded, size: 42, color: SaoColors.textMutedFor(context)),
                        const SizedBox(height: 8),
                        Text(summary, style: TextStyle(fontWeight: FontWeight.w700, color: SaoColors.textFor(context))),
                        const SizedBox(height: 4),
                        Text(emptyMessage, style: TextStyle(fontSize: 12, color: SaoColors.textMutedFor(context))),
                      ],
                    ),
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: _mapCenter(groupedPoints),
                    initialZoom: groupedPoints.length == 1 ? 11.0 : 8.0,
                    initialCameraFit: groupedPoints.length > 1
                        ? CameraFit.bounds(
                            bounds: _mapBounds(groupedPoints),
                            padding: const EdgeInsets.all(40),
                          )
                        : null,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'mx.sao.desktop',
                    ),
                    CircleLayer(
                      circles: visibleMarkers.map((entry) {
                        final color = SaoColors.getRiskColor(entry.item.risk);
                        final isSelected = entry.item.id == _selectedMapPointId;
                        return CircleMarker(
                          point: entry.point,
                          radius: isSelected ? 13 : 9,
                          color: color.withValues(alpha: isSelected ? 0.82 : 0.58),
                          borderColor: isSelected ? Colors.white : color,
                          borderStrokeWidth: isSelected ? 2.0 : 1.2,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: visibleMarkers.map((entry) {
                        final item = entry.item;
                        final color = SaoColors.getRiskColor(item.risk);
                        final isSelected = item.id == _selectedMapPointId;
                        return Marker(
                          point: entry.point,
                          width: 42,
                          height: 46,
                          child: Tooltip(
                            message: _expandedMarkerTooltip(entry),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMapPointId = item.id),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: isSelected ? 34 : 30,
                                    color: isSelected ? SaoColors.info : color,
                                    shadows: const [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Color(0x66000000),
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  if (entry.groupSize > 1 && entry.groupIndex == 0)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SaoColors.gray900,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: Text(
                                          '${entry.groupSize}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minCardHeight),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: SaoColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SaoColors.borderFor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: SaoColors.gray600)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _mapMetricChip(
                      Icons.assignment_rounded,
                      '${points.length} actividades',
                    ),
                    _mapMetricChip(
                      Icons.place_rounded,
                      '${groupedPoints.length} ubicaciones',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            filtersSection,
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _legendChip(
                  'Todas',
                  SaoColors.gray600,
                  active: _planningStatusFilter == 'todos',
                  onTap: () => setState(() => _planningStatusFilter = 'todos'),
                ),
                _legendChip(
                  'Pendiente',
                  SaoColors.info,
                  active: _planningStatusFilter == 'PENDIENTE' || _planningStatusFilter == 'REVISION_PENDIENTE',
                  onTap: () => setState(() => _planningStatusFilter = 'REVISION_PENDIENTE'),
                ),
                _legendChip(
                  'En curso',
                  SaoColors.warning,
                  active: _planningStatusFilter == 'EN_CURSO',
                  onTap: () => setState(() => _planningStatusFilter = 'EN_CURSO'),
                ),
                _legendChip(
                  'Completada / validada',
                  SaoColors.success,
                  active: _planningStatusFilter == 'COMPLETADA',
                  onTap: () => setState(() => _planningStatusFilter = 'COMPLETADA'),
                ),
                _legendChip(
                  'Rechazada',
                  SaoColors.error,
                  active: _planningStatusFilter == 'RECHAZADO',
                  onTap: () => setState(() => _planningStatusFilter = 'RECHAZADO'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final showSidePanel = constraints.maxWidth >= 1050;
                if (!showSidePanel) {
                  return Column(
                    children: [
                      buildMapView(),
                      const SizedBox(height: 12),
                      _buildMapSelectionPanel(selectedPoint),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: buildMapView()),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: _buildMapSelectionPanel(selectedPoint),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: points
                  .take(6)
                  .map((item) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: SaoColors.surfaceRaisedFor(context),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: SaoColors.borderFor(context)),
                        ),
                        child: Text(
                          item.municipality.isNotEmpty || item.state.isNotEmpty
                              ? '${item.municipality}${item.state.isNotEmpty ? ' / ${item.state}' : ''}'
                              : (item.front.isNotEmpty ? item.front : item.label),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SaoColors.gray700,
                          ),
                        ),
                      ))
                  .toList(growable: false),
            ),
            if (points.length > 6) ...[
              const SizedBox(height: 8),
              Text(
                '+${points.length - 6} ubicaciones adicionales',
                style: const TextStyle(fontSize: 12, color: SaoColors.gray500),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Conteo por estado/municipio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (locationCounts.isEmpty)
              const _EmptyState(
                icon: Icons.location_off_outlined,
                iconColor: SaoColors.gray300,
                message: 'Sin ubicaciones disponibles',
              )
            else
              SizedBox(
                height: (locationCounts.length * 28.0).clamp(40.0, 160.0),
                child: Scrollbar(
                  controller: _mapLocationsScrollController,
                  thumbVisibility: locationCounts.length > 5,
                  child: ListView.builder(
                    controller: _mapLocationsScrollController,
                    itemCount: locationCounts.length,
                    itemBuilder: (context, index) {
                      final item = locationCounts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.label, style: const TextStyle(color: SaoColors.gray700))),
                            Text('${item.count}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mapMetricChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SaoColors.surfaceRaisedFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SaoColors.info),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SaoColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMapFilters(DashboardData data) {
    final activeCount = _searchFilterTags.length;

    void addTag(String raw) {
      final clean = cleanDashboardFilterValue(raw);
      if (clean.isEmpty) return;
      final exists = _searchFilterTags.any(
        (tag) => _dashboardCanonicalToken(tag) == _dashboardCanonicalToken(clean),
      );
      if (exists) {
        _searchFilterController.clear();
        return;
      }
      setState(() {
        _searchFilterTags.add(clean);
        _searchFilterController.clear();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchFilterController,
          onSubmitted: addTag,
          decoration: InputDecoration(
            hintText: 'Escribe y presiona Enter para filtrar por frente, estado o municipio',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Agregar filtro',
                  onPressed: () => addTag(_searchFilterController.text),
                  icon: const Icon(Icons.add_rounded),
                ),
                if (activeCount > 0)
                  IconButton(
                    tooltip: 'Limpiar filtros',
                    onPressed: () {
                      setState(() {
                        _searchFilterTags.clear();
                        _searchFilterController.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_rounded),
                  ),
              ],
            ),
            isDense: true,
            filled: true,
            fillColor: SaoColors.surfaceMutedFor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: SaoColors.borderFor(context)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_searchFilterTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchFilterTags
                .map(
                  (tag) => InputChip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        _searchFilterTags.removeWhere(
                          (value) => _dashboardCanonicalToken(value) == _dashboardCanonicalToken(tag),
                        );
                      });
                    },
                  ),
                )
                .toList(growable: false),
          )
        else
          Text(
            'Sin etiquetas activas. Ejemplos: TMQ, Guanajuato, Doctor Mora, Frente Norte.',
            style: TextStyle(fontSize: 12, color: SaoColors.textMutedFor(context)),
          ),
      ],
    );
  }

  LatLng _mapCenter(List<_GroupedGeoPoint> points) {
    final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final lon = points.map((p) => p.lon).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lon);
  }

  LatLngBounds _mapBounds(List<_GroupedGeoPoint> points) {
    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLon = points.first.lon;
    double maxLon = points.first.lon;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lon < minLon) minLon = p.lon;
      if (p.lon > maxLon) maxLon = p.lon;
    }
    return LatLngBounds(
      LatLng(minLat - 0.1, minLon - 0.1),
      LatLng(maxLat + 0.1, maxLon + 0.1),
    );
  }

  List<_GroupedGeoPoint> _groupMapPoints(List<DashboardGeoPoint> points) {
    final grouped = <String, List<DashboardGeoPoint>>{};
    for (final point in points) {
      final key = '${point.lat.toStringAsFixed(6)}|${point.lon.toStringAsFixed(6)}';
      grouped.putIfAbsent(key, () => <DashboardGeoPoint>[]).add(point);
    }

    return grouped.values
        .map(
          (items) => _GroupedGeoPoint(
            lat: items.first.lat,
            lon: items.first.lon,
            items: items,
          ),
        )
        .toList(growable: false);
  }

  String _expandedMarkerTooltip(_ExpandedGeoPoint entry) {
    final lines = <String>[
      entry.item.label,
      if (entry.item.municipality.isNotEmpty || entry.item.state.isNotEmpty)
        '${entry.item.municipality}${entry.item.state.isNotEmpty ? ' / ${entry.item.state}' : ''}',
      if (entry.item.front.isNotEmpty) 'Frente: ${entry.item.front}',
      if (entry.groupSize > 1) '${entry.groupIndex + 1} de ${entry.groupSize} actividades en la misma ubicación',
    ];
    return lines.join('\n');
  }

  List<_ExpandedGeoPoint> _expandMapMarkers(List<_GroupedGeoPoint> groups) {
    final result = <_ExpandedGeoPoint>[];

    for (final group in groups) {
      if (group.items.length <= 1) {
        result.add(
          _ExpandedGeoPoint(
            item: group.items.first,
            point: LatLng(group.lat, group.lon),
            groupIndex: 0,
            groupSize: 1,
          ),
        );
        continue;
      }

      final angleStep = (2 * math.pi) / group.items.length;
      final baseRadius = group.items.length <= 3 ? 0.0035 : 0.0045;
      final lonFactor = math.max(0.35, math.cos(group.lat * math.pi / 180).abs());

      for (var i = 0; i < group.items.length; i++) {
        final angle = (-math.pi / 2) + (angleStep * i);
        final latOffset = math.sin(angle) * baseRadius;
        final lonOffset = (math.cos(angle) * baseRadius) / lonFactor;
        result.add(
          _ExpandedGeoPoint(
            item: group.items[i],
            point: LatLng(group.lat + latOffset, group.lon + lonOffset),
            groupIndex: i,
            groupSize: group.items.length,
          ),
        );
      }
    }

    return result;
  }

  Widget _buildCriticalQueueTable(List<ValidationQueueItem> items) {
    final sorted = items.where(isCriticalDashboardQueueItem).toList()
      ..sort((a, b) {
        if (a.isOver24h == b.isOver24h) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return a.isOver24h ? -1 : 1;
      });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pendientes críticos por revisar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Solo se muestran actividades con riesgo alto, prioritario o con conflictos de validación.',
            style: TextStyle(color: SaoColors.gray600),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const _EmptyState(
              icon: Icons.local_cafe_rounded,
              iconColor: SaoColors.success,
              message: 'No hay actividades de riesgo alto, prioritario o con conflictos en esta vista',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(SaoColors.surfaceRaisedFor(context)),
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Proyecto')),
                  DataColumn(label: Text('Usuario')),
                  DataColumn(label: Text('Tipo')),
                  DataColumn(label: Text('PK / Ubicacion')),
                  DataColumn(label: Text('Riesgo')),
                  DataColumn(label: Text('Accion')),
                ],
                rows: sorted.take(25).map((item) {
                  final riskColor = SaoColors.getRiskColor(item.risk);
                  return DataRow(
                    color: item.isOver24h
                        ? WidgetStateProperty.all(SaoColors.alertBg)
                        : null,
                    cells: [
                      DataCell(Text(_shortId(item.id))),
                      DataCell(Text(item.projectId)),
                      DataCell(Text(item.userName)),
                      DataCell(Text(item.activityType)),
                      DataCell(Text('${item.pk} · ${item.municipality.isNotEmpty ? item.municipality : item.front}')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.risk.toUpperCase(),
                            style: TextStyle(color: riskColor, fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                      ),
                      DataCell(
                        FilledButton.icon(
                          onPressed: () => _openReviewPage(item.id),
                          style: item.isOver24h
                              ? FilledButton.styleFrom(
                                  backgroundColor: SaoColors.error,
                                  foregroundColor: Colors.white,
                                )
                              : null,
                          icon: const Icon(Icons.rate_review_rounded, size: 16),
                          label: const Text('Revisar ahora'),
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  String _encodedDashboardSearchQuery() {
    return _searchFilterTags.join('|');
  }

  bool _matchesDashboardQueueFilters(ValidationQueueItem item) {
    final encodedSearch = _encodedDashboardSearchQuery();
    final normalizedStatus = normalizeDashboardExecutionStatus(item.status);
    final normalizedRisk = normalizeDashboardRiskToken(item.risk);
    final normalizedReview = normalizeDashboardReviewStatus(item.status);

    if (_planningStatusFilter != 'todos' &&
        normalizedStatus != normalizeDashboardExecutionStatus(_planningStatusFilter)) {
      return false;
    }
    if (_planningRiskFilter != 'todos' &&
        normalizedRisk != normalizeDashboardRiskToken(_planningRiskFilter)) {
      return false;
    }
    if (_planningReviewFilter != 'todos') {
      final selectedReview = normalizeDashboardReviewStatus(_planningReviewFilter);
      if (normalizedReview != selectedReview && normalizedStatus != normalizeDashboardExecutionStatus(_planningReviewFilter)) {
        return false;
      }
    }
    if (!dashboardMatchesUserFilter(item.userName, _planningUserFilter)) return false;
    if (!dashboardMatchesValueFilter(item.front, _planningFrontFilter)) return false;
    if (!dashboardMatchesValueFilter(item.state, _planningStateFilter)) return false;
    if (!dashboardMatchesValueFilter(item.municipality, _planningMunicipalityFilter)) return false;

    final searchable = dashboardNormalizeSearchToken(
      [
        item.userName,
        item.activityType,
        item.pk,
        item.front,
        item.municipality,
        item.state,
      ].join(' '),
    );
    return dashboardMatchesSearchQuery(searchable, encodedSearch);
  }

  bool _hasDashboardFiltersActive() {
    return _searchFilterTags.isNotEmpty ||
        !dashboardMatchesValueFilter('', _planningStatusFilter) ||
        !dashboardMatchesValueFilter('', _planningRiskFilter) ||
        !dashboardMatchesValueFilter('', _planningReviewFilter) ||
        !dashboardMatchesValueFilter('', _planningUserFilter) ||
        !dashboardMatchesValueFilter('', _planningFrontFilter) ||
        !dashboardMatchesValueFilter('', _planningStateFilter) ||
        !dashboardMatchesValueFilter('', _planningMunicipalityFilter);
  }

  DashboardData _buildFilteredDashboardData(DashboardData data) {
    if (!_hasDashboardFiltersActive()) {
      return data;
    }

    final filteredGeoPoints = _filterPlanningMapPoints(data.geoPoints);
    final filteredQueue = _applyFilters(data.queueItems, includeKpiFilter: false);
    final riskCounts = <String, int>{'bajo': 0, 'medio': 0, 'alto': 0, 'prioritario': 0};
    final frontStats = <String, List<int>>{};
    var total = 0;
    var approved = 0;
    var pending = 0;
    var rejected = 0;
    var needsFix = 0;

    void registerFront(String rawFront, bool executed) {
      final front = cleanDashboardFilterValue(rawFront);
      if (front.isEmpty) return;
      final current = frontStats.putIfAbsent(front, () => [0, 0]);
      current[0] += 1;
      if (executed) {
        current[1] += 1;
      }
    }

    if (filteredGeoPoints.isNotEmpty) {
      for (final item in filteredGeoPoints) {
        total += 1;
        final status = _effectiveMapStatus(item);
        switch (status) {
          case 'COMPLETADA':
            approved += 1;
            break;
          case 'RECHAZADO':
            rejected += 1;
            break;
          case 'EN_CURSO':
            needsFix += 1;
            break;
          case 'REVISION_PENDIENTE':
          case 'PENDIENTE':
          default:
            pending += 1;
            break;
        }
        final normalizedRisk = normalizeDashboardRiskToken(item.risk);
        if (riskCounts.containsKey(normalizedRisk)) {
          riskCounts[normalizedRisk] = (riskCounts[normalizedRisk] ?? 0) + 1;
        }
        registerFront(item.front, status == 'COMPLETADA');
      }
    } else {
      for (final item in filteredQueue) {
        total += 1;
        final status = normalizeDashboardExecutionStatus(item.status);
        switch (status) {
          case 'COMPLETADA':
            approved += 1;
            break;
          case 'RECHAZADO':
            rejected += 1;
            break;
          case 'EN_CURSO':
            needsFix += 1;
            break;
          case 'REVISION_PENDIENTE':
          case 'PENDIENTE':
          default:
            pending += 1;
            break;
        }
        final normalizedRisk = normalizeDashboardRiskToken(item.risk);
        if (riskCounts.containsKey(normalizedRisk)) {
          riskCounts[normalizedRisk] = (riskCounts[normalizedRisk] ?? 0) + 1;
        }
        registerFront(item.front, status == 'COMPLETADA');
      }
    }

    final frontProgress = frontStats.entries
        .map((entry) => FrontProgressItem(front: entry.key, planned: entry.value[0], executed: entry.value[1]))
        .toList(growable: false)
      ..sort((a, b) => a.front.toLowerCase().compareTo(b.front.toLowerCase()));

    final locationCounts = filteredGeoPoints.isNotEmpty
        ? _locationCountsFor(filteredGeoPoints)
        : _locationCountsForQueue(filteredQueue);

    return DashboardData(
      pendingCount: pending,
      approvedCount: approved,
      rejectedCount: rejected,
      needsFixCount: needsFix,
      totalInQueue: total,
      projectId: data.projectId,
      range: data.range,
      approvedTrend: DashboardTrend(current: approved, previous: approved),
      rejectedTrend: DashboardTrend(current: rejected, previous: rejected),
      needsFixTrend: DashboardTrend(current: needsFix, previous: needsFix),
      pendingTrend: DashboardTrend(current: pending, previous: pending),
      queueItems: filteredQueue,
      geoPoints: filteredGeoPoints,
      topErrors: data.topErrors,
      locationCounts: locationCounts,
      riskCounts: riskCounts,
      frontProgress: frontProgress,
      avgValidationHours: total == 0 ? 0 : data.avgValidationHours,
    );
  }

  List<LocationCountItem> _locationCountsForQueue(List<ValidationQueueItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      final label = item.municipality.isNotEmpty
          ? '${item.municipality}${item.state.isNotEmpty ? ' / ${item.state}' : ''}'
          : (item.front.isNotEmpty ? item.front : 'Sin ubicacion');
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final result = counts.entries
        .map((entry) => LocationCountItem(label: entry.key, count: entry.value))
        .toList(growable: false);
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  List<ValidationQueueItem> _applyFilters(List<ValidationQueueItem> items, {bool includeKpiFilter = true}) {
    return items.where((item) {
      if (includeKpiFilter && !dashboardMatchesKpiFilter(item, _kpiFilter)) return false;
      return _matchesDashboardQueueFilters(item);
    }).toList(growable: false);
  }

  List<DashboardGeoPoint> _filterPlanningMapPoints(List<DashboardGeoPoint> items) {
    return items
        .where(
          (item) => dashboardPointMatchesPlanningFilters(
            item,
            statusFilter: _planningStatusFilter,
            riskFilter: _planningRiskFilter,
            reviewFilter: _planningReviewFilter,
            userFilter: _planningUserFilter,
            frontFilter: _planningFrontFilter,
            stateFilter: _planningStateFilter,
            municipalityFilter: _planningMunicipalityFilter,
            searchQuery: _encodedDashboardSearchQuery(),
          ),
        )
        .toList(growable: false);
  }

  List<LocationCountItem> _locationCountsFor(List<DashboardGeoPoint> points) {
    final counts = <String, int>{};
    for (final item in points) {
      final label = item.municipality.isNotEmpty
          ? '${item.municipality}${item.state.isNotEmpty ? ' / ${item.state}' : ''}'
          : (item.front.isNotEmpty ? item.front : 'Sin ubicacion');
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final result = counts.entries
        .map((entry) => LocationCountItem(label: entry.key, count: entry.value))
        .toList(growable: false);
    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

  String _normalizeExecutionStatus(String raw) {
    return normalizeDashboardExecutionStatus(raw);
  }

  String _effectiveMapStatus(DashboardGeoPoint point) {
    return dashboardEffectiveMapStatus(point);
  }

  String _normalizeReviewStatus(String raw) {
    return normalizeDashboardReviewStatus(raw);
  }

  String _trendSubtitle(DashboardTrend trend) {
    if (trend.previous == 0 && trend.current == 0) return 'Sin cambios vs periodo anterior';
    if (trend.delta == 0) return 'Sin cambios vs periodo anterior';
    final direction = trend.delta > 0 ? 'subiendo' : 'bajando';
    return '${trend.delta.abs()} vs periodo anterior · $direction';
  }

  List<double> _sparklinePoints(DashboardTrend trend) {
    final prev = trend.previous.toDouble();
    final curr = trend.current.toDouble();
    final mid = (prev + curr) / 2;
    final floor = (prev * 0.7).clamp(0.0, double.infinity).toDouble();
    return [floor, prev, mid, curr];
  }

  String _shortId(String id) {
    if (id.length <= 10) return id;
    return '${id.substring(0, 8)}...';
  }

  DashboardGeoPoint? _resolveSelectedMapPoint(List<DashboardGeoPoint> points) {
    if (points.isEmpty) return null;
    for (final point in points) {
      if (point.id == _selectedMapPointId) return point;
    }
    return points.first;
  }

  Widget _legendChip(
    String label,
    Color color, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.28), width: active ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSelectionPanel(DashboardGeoPoint? point) {
    final canOpenReview = point != null && _canOpenReview(point);
    final canViewPdf = point != null && _canViewPdf(point);
    final isValidated = point != null && _isValidated(point);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaoColors.surfaceMutedFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: point == null
          ? const _EmptyState(
              icon: Icons.touch_app_rounded,
              iconColor: SaoColors.info,
              message: 'Selecciona un punto en el mapa para ver detalle y acciones.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalle del punto', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(point.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _legendChip(_effectiveMapStatus(point).replaceAll('_', ' '), _statusColor(_effectiveMapStatus(point))),
                    _legendChip(point.risk.toUpperCase(), SaoColors.getRiskColor(point.risk)),
                    if (isValidated)
                      _legendChip('Validada', SaoColors.success)
                    else if (canOpenReview)
                      _legendChip('En validación', SaoColors.info),
                  ],
                ),
                const SizedBox(height: 12),
                _mapDetailRow(Icons.folder_open_rounded, frontTerminology(point.projectId, capitalize: true), point.front.isEmpty ? 'Sin ${frontTerminology(point.projectId)}' : point.front),
                _mapDetailRow(Icons.place_rounded, 'Ubicación', '${point.municipality.isEmpty ? 'Sin municipio' : point.municipality}${point.state.isNotEmpty ? ' / ${point.state}' : ''}'),
                _mapDetailRow(Icons.person_outline_rounded, 'Responsable', (point.assignedName ?? '').trim().isEmpty ? 'Sin responsable' : point.assignedName!),
                _mapDetailRow(Icons.tag_rounded, 'ID', point.id),
                _mapDetailRow(Icons.gps_fixed_rounded, 'Coordenadas', '${point.lat.toStringAsFixed(5)}, ${point.lon.toStringAsFixed(5)}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canOpenReview)
                      FilledButton.icon(
                        onPressed: () => _openReviewPage(point.id),
                        icon: const Icon(Icons.rate_review_rounded, size: 16),
                        label: const Text('Abrir revisión'),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: (isValidated ? SaoColors.success : SaoColors.gray600).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (isValidated ? SaoColors.success : SaoColors.gray600).withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          isValidated ? 'Validada' : 'Sin revisión activa',
                          style: TextStyle(
                            color: isValidated ? SaoColors.success : SaoColors.gray700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (canViewPdf)
                      OutlinedButton.icon(
                        onPressed: () => _openPdfForPoint(point),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Ver PDF'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: point.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID de actividad copiado')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar ID'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _mapDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: SaoColors.gray600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: SaoColors.gray700, fontSize: 12),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String raw) {
    return switch (_normalizeExecutionStatus(raw)) {
      'COMPLETADA' => SaoColors.success,
      'EN_CURSO' => SaoColors.warning,
      'RECHAZADO' => SaoColors.error,
      'REVISION_PENDIENTE' => SaoColors.info,
      _ => SaoColors.primary,
    };
  }

  bool _canOpenReview(DashboardGeoPoint point) {
    final executionStatus = _effectiveMapStatus(point);
    final reviewStatus = _normalizeReviewStatus(point.reviewStatus);
    if (_isValidated(point)) return false;
    return executionStatus == 'REVISION_PENDIENTE' || reviewStatus == 'PENDIENTE_REVISION';
  }

  bool _canViewPdf(DashboardGeoPoint point) {
    return point.hasReport == true || _effectiveMapStatus(point) == 'COMPLETADA';
  }

  bool _isValidated(DashboardGeoPoint point) {
    final reviewStatus = _normalizeReviewStatus(point.reviewStatus);
    final reviewDecision = _normalizeReviewStatus(point.reviewDecision ?? '');
    return reviewStatus == 'APROBADO' || reviewDecision == 'APROBADO';
  }

  Future<void> _openPdfForPoint(DashboardGeoPoint point) async {
    try {
      final activityId = point.id.trim();
      final localPath = await findExistingLocalReportPath(
        activityId: activityId,
        projectId: point.projectId,
        front: point.front,
        state: point.state,
        municipality: point.municipality,
        activityType: point.label,
      );

      if (localPath != null && localPath.trim().isNotEmpty) {
        final opened = await _openDashboardLocalPath(localPath);
        if (opened) {
          return;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se encontró el PDF local, pero no se pudo abrir')),
        );
        return;
      }

      if (activityId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar la actividad para recuperar el PDF')),
        );
        return;
      }

      if (!mounted) return;
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('PDF no encontrado localmente'),
          content: const Text('Este PDF no está guardado en este equipo. ¿Quieres descargarlo de la nube?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Descargar'),
            ),
          ],
        ),
      );

      if (shouldDownload != true) return;

      final detail = await ref.read(completedActivityDetailProvider(activityId).future);
      final pdfEvidence = _selectPdfEvidenceForDownload(detail);
      if (pdfEvidence == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay una copia PDF disponible en la nube para esta actividad')),
        );
        return;
      }

      final file = await _downloadPdfFromCloud(detail, pdfEvidence);
      if (!mounted) return;
      final opened = await _openDashboardLocalPath(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened ? 'PDF descargado y abierto' : 'PDF descargado en ${file.path}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $error')),
      );
    }
  }

  Future<File> _downloadPdfFromCloud(
    CompletedActivityDetail detail,
    EvidenceItem evidence,
  ) async {
    final signedUrl = await EvidenceRepository().getDownloadSignedUrl(evidence.id);
    final uri = Uri.parse(signedUrl);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('No se pudo descargar PDF (${response.statusCode})');
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const FileSystemException('El PDF descargado llegó vacío');
    }

    final docsRootPath = await _resolveDashboardDocumentsRootPath();
    final projectFolder = _sanitizePdfFolderSegment(detail.summary.projectId, fallback: 'GENERAL');
    final frontFolder = _sanitizePdfFolderSegment(detail.summary.front, fallback: 'SIN_FRENTE');
    final stateFolder = _sanitizePdfFolderSegment(detail.summary.estado, fallback: 'SIN_ESTADO');
    final municipalityFolder = _sanitizePdfFolderSegment(detail.summary.municipio, fallback: 'SIN_MUNICIPIO');
    final activityFolder = _sanitizePdfFolderSegment(detail.summary.activityType, fallback: 'ACTIVIDAD');
    final expedienteFolder = _sanitizePdfFolderSegment(detail.summary.id, fallback: 'SIN_ID');
    final activityDir = Directory(
      '$docsRootPath/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/Reportes',
    );
    if (!await activityDir.exists()) {
      await activityDir.create(recursive: true);
    }

    final file = File('${activityDir.path}/${_inferPdfFileName(evidence, detail.summary.id)}');
    await file.writeAsBytes(bytes, flush: true);

    await registerDownloadedReportReference(
      activityId: detail.summary.id,
      file: file,
      sourceEvidenceId: evidence.id,
      generatedAt: evidence.uploadedAt,
    );

    return file;
  }

  void _openReviewPage(String activityId) {
    ref.read(operationsHubActivityIdProvider.notifier).state = activityId;
    ref.read(operationsHubTabIndexProvider.notifier).state = 0;
    ref.read(appShellIndexProvider.notifier).state = 2;
    ref.read(appRefreshTokenProvider.notifier).state++;
  }

  // ── Expediente General: Diálogo y Export (solo admin@sao.mx) ─────────────

  /// Muestra el diálogo de confirmación para descargar el expediente general.
  Future<void> _showBulkExpedienteDialog(List<String> projectOptions) async {
    if (_exportingExpediente || !mounted) return;

    final available = projectOptions.where((p) => p.isNotEmpty).toList()..sort();
    final selected = <String>{...available};

    // Rango de fechas por defecto: último año
    var pickedFrom = DateTime.now().subtract(const Duration(days: 365));
    var pickedTo   = DateTime.now();

    final confirmed = await showDialog<(Set<String>, DateTime, DateTime)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final allSelected = selected.length == available.length;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.folder_zip_rounded),
                SizedBox(width: 8),
                Text('Descargar Expediente General'),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se descargará una carpeta SAO_Expediente organizada por proyectos, '
                    'frentes y actividades, con el PDF y evidencias de cada una.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  // ─ Rango de fechas ──────────────────────────────────────────
                  const Text(
                    'Período de actividades:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerButton(
                          label: 'Desde',
                          date: pickedFrom,
                          firstDate: DateTime(2020),
                          lastDate: pickedTo,
                          onPicked: (d) => setDlgState(() => pickedFrom = d),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DatePickerButton(
                          label: 'Hasta',
                          date: pickedTo,
                          firstDate: pickedFrom,
                          lastDate: DateTime.now(),
                          onPicked: (d) => setDlgState(() => pickedTo = d),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Proyectos a incluir:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  if (available.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay proyectos disponibles.'),
                    )
                  else ...[
                    CheckboxListTile(
                      title: Text(
                        allSelected ? 'Deseleccionar todos' : 'Seleccionar todos',
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: allSelected,
                      tristate: true,
                      onChanged: (_) {
                        setDlgState(() {
                          if (allSelected) {
                            selected.clear();
                          } else {
                            selected.addAll(available);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          children: available
                              .map(
                                (p) => CheckboxListTile(
                                  title: Text(p, style: const TextStyle(fontSize: 13)),
                                  value: selected.contains(p),
                                  onChanged: (v) {
                                    setDlgState(() {
                                      if (v == true) {
                                        selected.add(p);
                                      } else {
                                        selected.remove(p);
                                      }
                                    });
                                  },
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta operación puede tardar varios minutos dependiendo '
                            'del número de actividades y evidencias.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(
                          ctx,
                          (Set<String>.from(selected), pickedFrom, pickedTo),
                        ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Descargar expediente'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || confirmed.$1.isEmpty || !mounted) return;
    await _runBulkExpedienteExport(
      confirmed.$1.toList()..sort(),
      confirmed.$2,
      confirmed.$3,
    );
  }

  /// Ejecuta la descarga masiva del expediente.
  Future<void> _runBulkExpedienteExport(
    List<String> projectIds,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    if (!mounted) return;
    setState(() => _exportingExpediente = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final docsRoot = await _resolveDashboardDocumentsRootPath();
      final expedienteRoot = Directory('$docsRoot/SAO_Expediente');
      await expedienteRoot.create(recursive: true);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Obteniendo lista de actividades…'),
          duration: Duration(seconds: 60),
        ),
      );

      final allActivities = <CompletedActivity>[];
      for (final projectId in projectIds) {
        try {
          final fetched = await _fetchAllCompletedActivities({
            'project_id': projectId,
            'date_from': dateFrom.toIso8601String(),
            'date_to': dateTo.toIso8601String(),
          });
          allActivities.addAll(fetched);
        } catch (_) {
          // continuar con el siguiente proyecto
        }
      }

      final total = allActivities.length;
      int processed = 0;
      int failed = 0;

      if (total == 0) {
        if (mounted) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('No se encontraron actividades para exportar.')),
            );
        }
        return;
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Descargando expediente: $total actividades…'),
            duration: const Duration(seconds: 120),
          ),
        );

      const apiClient = BackendApiClient();

      for (var i = 0; i < allActivities.length; i += 4) {
        final batch = allActivities.sublist(i, (i + 4).clamp(0, allActivities.length));

        await Future.wait(
          batch.map((activity) async {
            try {
              final decoded = await apiClient
                  .getJson(
                    '/api/v1/completed-activities/${Uri.encodeComponent(activity.id)}',
                  )
                  .timeout(const Duration(seconds: 30));

              if (decoded is! Map<String, dynamic>) return;

              final detail = CompletedActivityDetail.fromJson(decoded);
              final actDir = _expedienteActivityDir(expedienteRoot.path, detail.summary);
              final evidenciasDir = Directory('${actDir.path}/evidencias');
              await actDir.create(recursive: true);
              await evidenciasDir.create(recursive: true);

              // Descargar evidencias primero para poder referenciar rutas
              // locales al generar el PDF (evita doble descarga).
              final localPaths = await _expedienteDownloadEvidences(evidenciasDir.path, detail);
              await _expedienteGeneratePdf(actDir.path, detail, localPaths);

              processed++;
            } catch (_) {
              failed++;
            }
          }),
        );

        if (mounted) {
          final done = processed + failed;
          if (done < total) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Expediente: $done/$total actividades procesadas…'),
                  duration: const Duration(seconds: 60),
                ),
              );
          }
        }
      }

      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              failed == 0
                  ? 'Expediente descargado: $processed actividades. '
                      'Carpeta: ${expedienteRoot.path}'
                  : 'Expediente: $processed completadas, $failed con error. '
                      'Carpeta: ${expedienteRoot.path}',
            ),
            duration: const Duration(seconds: 20),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () => _openDashboardLocalPath(expedienteRoot.path),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Error al descargar expediente: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _exportingExpediente = false);
    }
  }

  /// Obtiene todas las actividades completadas (paginadas) para el proyecto dado.
  Future<List<CompletedActivity>> _fetchAllCompletedActivities(
    Map<String, String> params,
  ) async {
    const apiClient = BackendApiClient();
    const pageSize = 200;
    const maxItems = 5000;

    final all = <CompletedActivity>[];
    int page = 1;

    while (true) {
      final pageParams = <String, String>{
        ...params,
        'page': '$page',
        'page_size': '$pageSize',
      };
      final qs = pageParams.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');

      final decoded = await apiClient
          .getJson('/api/v1/completed-activities?$qs')
          .timeout(const Duration(seconds: 30));

      if (decoded is! Map<String, dynamic>) break;
      final items = decoded['items'];
      if (items is! List || items.isEmpty) break;

      all.addAll(
        items.whereType<Map<String, dynamic>>().map(CompletedActivity.fromJson),
      );

      final hasNext = decoded['has_next'] as bool? ?? false;
      if (!hasNext || all.length >= maxItems) break;
      page++;
    }

    return all;
  }

  /// Genera el PDF de una actividad en su carpeta del expediente.
  Future<void> _expedienteGeneratePdf(
    String actDirPath,
    CompletedActivityDetail detail,
    Map<String, String> localPaths,
  ) async {
    final s = detail.summary;
    final now = DateTime.now();
    await generateActivitiesPdf(
      [
        ReportActivityItem(
          id: s.id,
          projectId: s.projectId,
          title: s.title,
          activityType: s.activityType,
          pk: s.pk,
          frontName: s.front.isEmpty ? 'Sin frente' : s.front,
          status: s.reviewDecision.isEmpty ? 'COMPLETADA' : s.reviewDecision,
          reviewDecision: s.reviewDecision,
          reviewStatus: s.reviewDecision,
          createdAt: s.reviewedAt.isNotEmpty ? s.reviewedAt : s.createdAt,
          assignedName: s.assignedName,
          municipality: s.municipio,
          state: s.estado,
          colony: detail.colonia,
          notes: detail.reviewNotes,
          pendingEvidence: detail.evidences.isEmpty,
          hasReport: s.hasReport,
          evidences: detail.evidences
              .map(
                (e) => ReportEvidenceItem(
                  id: e.id,
                  // Usar ruta local si ya fue descargada; de lo contrario
                  // el generador de PDF la resolverá via signed URL.
                  filePath: localPaths[e.id] ?? e.gcsPath,
                  fileType: e.type,
                  caption: e.description,
                  capturedAt: e.uploadedAt,
                ),
              )
              .toList(growable: false),
        ),
      ],
      ReportFilters(
        projectId: s.projectId,
        frontName: s.front.isEmpty ? 'Todos' : s.front,
        dateRange: ReportDateRange(
          start: now.subtract(const Duration(days: 730)),
          end: now,
        ),
        includeAlreadyReported: true,
      ),
      executiveSummary: detail.reviewNotes,
      includeAudit: true,
      includeNotes: true,
      includeAttachments: true,
      saveFilePath: '$actDirPath/reporte_actividad.pdf',
    );
  }

  /// Descarga todas las evidencias de una actividad a la carpeta indicada.
  /// Retorna un mapa de evidenceId → ruta local absoluta para los archivos
  /// que se descargaron exitosamente (se usa para embeber en el PDF).
  Future<Map<String, String>> _expedienteDownloadEvidences(
    String evidenciasDirPath,
    CompletedActivityDetail detail,
  ) async {
    final evidenceRepo = EvidenceRepository();
    final localPaths = <String, String>{};
    for (var idx = 0; idx < detail.evidences.length; idx++) {
      final evidence = detail.evidences[idx];
      try {
        final signedUrl = await evidenceRepo
            .getDownloadSignedUrl(evidence.id)
            .timeout(const Duration(seconds: 15));

        final ext = _expedienteGuessExtension(evidence, signedUrl);
        final idLen = detail.summary.id.length.clamp(0, 8);
        final pkPart = _sanitizeExpedienteSegment(
          detail.summary.pk.isNotEmpty
              ? detail.summary.pk
              : detail.summary.id.substring(0, idLen),
        );
        final descPart = _sanitizeExpedienteSegment(
          evidence.description.isNotEmpty
              ? evidence.description
              : 'evidencia_${idx + 1}',
        );
        final fileName =
            '${(idx + 1).toString().padLeft(2, '0')}_${pkPart}_$descPart$ext';

        final targetFile = File('$evidenciasDirPath/$fileName');
        if (await targetFile.exists() && await targetFile.length() > 0) {
          localPaths[evidence.id] = targetFile.path;
          continue;
        }

        await _expedienteDownloadFile(signedUrl, targetFile);
        if (await targetFile.exists() && await targetFile.length() > 0) {
          localPaths[evidence.id] = targetFile.path;
        }
      } catch (_) {
        // Continuar si una evidencia falla individualmente
      }
    }
    return localPaths;
  }

  /// Descarga un archivo desde una URL firmada a un File local.
  Future<void> _expedienteDownloadFile(String signedUrl, File targetFile) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(signedUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'SAO-Desktop/1.0');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      if (bytes.isNotEmpty) {
        await targetFile.writeAsBytes(bytes, flush: true);
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Construye el directorio de la actividad dentro del expediente.
  Directory _expedienteActivityDir(String rootPath, CompletedActivity s) {
    final project = _sanitizeExpedienteSegment(
      s.projectId.isNotEmpty ? s.projectId : 'SIN_PROYECTO',
    );
    final estado = _sanitizeExpedienteSegment(
      s.estado.isNotEmpty ? s.estado : 'SIN_ESTADO',
    );
    final municipio = _sanitizeExpedienteSegment(
      s.municipio.isNotEmpty ? s.municipio : 'SIN_MUNICIPIO',
    );
    final front = _sanitizeExpedienteSegment(
      s.front.isNotEmpty ? s.front : 'SIN_FRENTE',
    );
    final title = _sanitizeExpedienteSegment(
      s.title.isNotEmpty ? s.title : 'ACTIVIDAD',
    );
    final pk =
        s.pk.trim().isNotEmpty ? '__${_sanitizeExpedienteSegment(s.pk)}' : '';
    return Directory('$rootPath/$project/$front/$estado/$municipio/$title$pk');
  }

  /// Sanitiza un segmento de ruta para el sistema de archivos.
  String _sanitizeExpedienteSegment(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    final compact = cleaned.replaceAll(RegExp(r'\s+'), '_');
    final result = compact.isEmpty ? 'sin_dato' : compact;
    return result.length > 80 ? result.substring(0, 80) : result;
  }

  /// Infiere la extensión del archivo de una evidencia.
  String _expedienteGuessExtension(EvidenceItem evidence, String signedUrl) {
    String fromRaw(String raw) {
      if (raw.trim().isEmpty) return '';
      final withoutQuery = raw.split('?').first;
      final dotIdx = withoutQuery.lastIndexOf('.');
      if (dotIdx < 0 || dotIdx >= withoutQuery.length - 1) return '';
      return withoutQuery.substring(dotIdx);
    }

    final fromGcs = fromRaw(evidence.gcsPath);
    if (fromGcs.isNotEmpty) return fromGcs;

    final fromUrl = fromRaw(signedUrl);
    if (fromUrl.isNotEmpty) return fromUrl;

    final upper = evidence.type.toUpperCase();
    if (upper.contains('PDF') || upper.contains('DOCUMENT')) return '.pdf';
    if (upper.contains('VIDEO')) return '.mp4';
    return '.jpg';
  }
}

class _GroupedGeoPoint {
  final double lat;
  final double lon;
  final List<DashboardGeoPoint> items;

  const _GroupedGeoPoint({
    required this.lat,
    required this.lon,
    required this.items,
  });
}

class _ExpandedGeoPoint {
  final DashboardGeoPoint item;
  final LatLng point;
  final int groupIndex;
  final int groupSize;

  const _ExpandedGeoPoint({
    required this.item,
    required this.point,
    required this.groupIndex,
    required this.groupSize,
  });
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final delta = (maxV - minV).abs() < 0.001 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - minV) / delta * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Filled area under the sparkline
    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}


// ---------------------------------------------------------------------------
// Shared empty-state widget
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.iconColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: iconColor.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: SaoColors.gray500)),
          ],
        ),
      ),
    );
  }
}

// ── Helper: botón que abre un DatePicker ─────────────────────────────────────

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  final String label;
  final DateTime date;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'es');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: firstDate,
          lastDate: lastDate,
          locale: const Locale('es'),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 14),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(fmt.format(date),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
