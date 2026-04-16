import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../features/auth/app_session_controller.dart';

enum DashboardRange { today, week, month, all }

enum DashboardKpiFilter { all, approved, rejected, needsFix, pending }

class DashboardTrend {
  final int current;
  final int previous;

  const DashboardTrend({
    required this.current,
    required this.previous,
  });

  int get delta => current - previous;
}

class DashboardData {
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int needsFixCount;
  final int totalInQueue;
  final String projectId;
  final DashboardRange range;
  final DashboardTrend approvedTrend;
  final DashboardTrend rejectedTrend;
  final DashboardTrend needsFixTrend;
  final DashboardTrend pendingTrend;
  final List<ValidationQueueItem> queueItems;
  final List<DashboardGeoPoint> geoPoints;
  final List<TopErrorItem> topErrors;
  final List<LocationCountItem> locationCounts;
  final Map<String, int> riskCounts;
  final List<FrontProgressItem> frontProgress;
  final double avgValidationHours;

  const DashboardData({
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.needsFixCount,
    required this.totalInQueue,
    required this.projectId,
    required this.range,
    required this.approvedTrend,
    required this.rejectedTrend,
    required this.needsFixTrend,
    required this.pendingTrend,
    required this.queueItems,
    required this.geoPoints,
    required this.topErrors,
    required this.locationCounts,
    required this.riskCounts,
    required this.frontProgress,
    required this.avgValidationHours,
  });

  double get avancePct {
    if (totalInQueue == 0) return 0;
    return (approvedCount / totalInQueue).clamp(0, 1).toDouble();
  }
}

class DashboardGeoPoint {
  final String id;
  final String projectId;
  final String risk;
  final String status;
  final String reviewStatus;
  final String? reviewDecision;
  final String front;
  final String municipality;
  final String state;
  final String label;
  final String? assignedToUserId;
  final String? assignedName;
  final double lat;
  final double lon;
  final bool hasReport;

  const DashboardGeoPoint({
    required this.id,
    required this.projectId,
    required this.risk,
    required this.status,
    required this.reviewStatus,
    this.reviewDecision,
    required this.front,
    required this.municipality,
    required this.state,
    required this.label,
    this.assignedToUserId,
    this.assignedName,
    required this.lat,
    required this.lon,
    required this.hasReport,
  });
}

class ValidationQueueItem {
  final String id;
  final String projectId;
  final String userName;
  final String activityType;
  final String pk;
  final String front;
  final String municipality;
  final String risk;
  final String severity;
  final String status;
  final DateTime createdAt;
  final double? lat;
  final double? lon;

  const ValidationQueueItem({
    required this.id,
    required this.projectId,
    required this.userName,
    required this.activityType,
    required this.pk,
    required this.front,
    required this.municipality,
    required this.risk,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.lat,
    this.lon,
  });

  bool get isOver24h => DateTime.now().toUtc().difference(createdAt.toUtc()) > const Duration(hours: 24);
}

class TopErrorItem {
  final String label;
  final int count;

  const TopErrorItem({required this.label, required this.count});
}

class LocationCountItem {
  final String label;
  final int count;

  const LocationCountItem({required this.label, required this.count});
}

class FrontProgressItem {
  final String front;
  final int planned;
  final int executed;

  const FrontProgressItem({
    required this.front,
    required this.planned,
    required this.executed,
  });
}

class DashboardActivityMetrics {
  final int total;
  final int pending;
  final int approved;
  final int rejected;
  final int needsFix;

  const DashboardActivityMetrics({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.needsFix,
  });
}

final selectedDashboardRangeProvider = StateProvider<DashboardRange>((_) => DashboardRange.today);

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  const client = BackendApiClient();
  final user = ref.watch(currentAppUserProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
  final availableProjects = await ref.watch(availableProjectsProvider.future);
  final range = ref.watch(selectedDashboardRangeProvider);

  final now = DateTime.now().toUtc();
  final currentStart = _rangeStart(now, range);
  final projectQuery = activeProjectId.isEmpty
      ? ''
      : '?project_id=${Uri.encodeQueryComponent(activeProjectId)}';

  try {
    final decoded = await _tryGetJsonMap(client, '/api/v1/dashboard/kpis$projectQuery');
    if (decoded == null) return _empty(user, range);

    final queueDecoded = await _tryGetJsonMap(client, '/api/v1/review/queue$projectQuery');
    final reportsCurrent = await _tryGetJsonMap(
      client,
      '/api/v1/reports/activities${_reportsQuery(projectId: activeProjectId, from: currentStart, to: now)}',
    );
    final activitiesDecoded = await _loadActivitiesDataset(
      client,
      activeProjectId: activeProjectId,
      availableProjects: availableProjects,
    );

    final counters = decoded['kpis'] as Map<String, dynamic>? ?? decoded;
    final backlogByState = _asStringIntMap(counters['backlog_by_state']);
    final queueItemsRaw = queueDecoded?['items'] as List<dynamic>? ?? const [];
    final reportCurrentItems = (reportsCurrent?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final activityItems = (activitiesDecoded?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final mergedSourceItems = mergeDashboardMapSourceItems(activityItems, reportCurrentItems);
    final allActivityItems = activityItems.isNotEmpty ? activityItems : mergedSourceItems;
    final activityScopeItems = filterDashboardItemsByRange(allActivityItems, range, now);
    final mapSourceItems = filterDashboardItemsByRange(mergedSourceItems, range, now);
    final visualItems = filterDashboardItemsByRange(
      reportCurrentItems.isNotEmpty ? reportCurrentItems : allActivityItems,
      range,
      now,
    );
    final activityMetrics = summarizeDashboardActivityMetrics(activityScopeItems);
    final trendMetrics = buildDashboardTrends(allActivityItems, range, now);

    final pendingCount = activityMetrics.total > 0
        ? activityMetrics.pending
        : (counters['review_queue_count'] as num?)?.toInt() ??
            (counters['pending_review'] as num?)?.toInt() ??
            backlogByState['REVISION_PENDIENTE'] ??
            0;
    final approvedCount = activityMetrics.total > 0
        ? activityMetrics.approved
        : (counters['completed'] as num?)?.toInt() ??
            (counters['completed_today'] as num?)?.toInt() ??
            (counters['approved'] as num?)?.toInt() ??
            backlogByState['COMPLETADA'] ??
            0;
    final rejectedCount = activityMetrics.total > 0
        ? activityMetrics.rejected
        : (counters['overdue_review_count'] as num?)?.toInt() ??
            (queueDecoded?['counters']?['rejected'] as num?)?.toInt() ??
            0;
    final needsFixCount = activityMetrics.total > 0
        ? activityMetrics.needsFix
        : (counters['in_progress'] as num?)?.toInt() ??
            (counters['pending_today'] as num?)?.toInt() ??
            backlogByState['EN_CURSO'] ??
            0;

    final projectId = (decoded['project_id'] ?? 'N/A').toString();

    final queueItems = queueItemsRaw
        .whereType<Map<String, dynamic>>()
        .map<ValidationQueueItem>(_mapQueueItem)
        .toList(growable: false);
    final geoPoints = _buildGeoPoints(mapSourceItems);

    final topErrors = _buildTopErrors(queueItemsRaw);
    final locationCounts = _buildLocationCounts(geoPoints).take(8).toList(growable: false);
    final riskCounts = _buildRiskCounts(geoPoints);
    final frontProgress = _buildFrontProgress(activityScopeItems);

    final approvedTrend = trendMetrics['approved']!;
    final pendingTrend = trendMetrics['pending']!;
    final needsFixTrend = trendMetrics['needsFix']!;
    final rejectedTrend = trendMetrics['rejected']!;

    final avgValidationHours = _computeAvgValidationHours(visualItems, now);
    final totalInScope = activityMetrics.total > 0 ? activityMetrics.total : activityScopeItems.length;

    return DashboardData(
      pendingCount: pendingCount,
      approvedCount: approvedCount,
      rejectedCount: rejectedCount,
      needsFixCount: needsFixCount,
        totalInQueue: totalInScope > 0
            ? totalInScope
            : (counters['total_activities'] as num?)?.toInt() ??
                (counters['total'] as num?)?.toInt() ??
                (pendingCount + approvedCount + rejectedCount + needsFixCount),
      projectId: projectId,
      range: range,
      approvedTrend: approvedTrend,
      rejectedTrend: rejectedTrend,
      needsFixTrend: needsFixTrend,
      pendingTrend: pendingTrend,
      queueItems: queueItems,
      geoPoints: geoPoints,
      topErrors: topErrors,
      locationCounts: locationCounts,
      riskCounts: riskCounts,
      frontProgress: frontProgress,
      avgValidationHours: avgValidationHours,
    );
  } catch (_) {
    return _empty(user, range);
  }
});

Future<Map<String, dynamic>?> _tryGetJsonMap(
  BackendApiClient client,
  String path,
) async {
  try {
    final decoded = await client.getJson(path);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return null;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _loadActivitiesDataset(
  BackendApiClient client, {
  required String activeProjectId,
  required List<String> availableProjects,
}) async {
  Future<List<Map<String, dynamic>>> loadProjectActivities(String projectId) async {
    final mergedItems = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    var page = 1;

    while (page <= 20) {
      final decoded = await _tryGetJsonMap(
        client,
        '/api/v1/activities${_activitiesQuery(projectId: projectId, page: page, pageSize: 100)}',
      );
      if (decoded == null) break;

      final items = decoded['items'];
      if (items is! List || items.isEmpty) break;

      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final id = _resolveDashboardPointId(raw);
        if (id.isNotEmpty && !seenIds.add(id)) continue;
        mergedItems.add(raw);
      }

      if (decoded['has_next'] != true) break;
      page += 1;
    }

    return mergedItems;
  }

  if (activeProjectId.isNotEmpty) {
    return {'items': await loadProjectActivities(activeProjectId)};
  }

  final normalizedProjects = availableProjects
      .map((projectId) => projectId.trim().toUpperCase())
      .where((projectId) => projectId.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (normalizedProjects.isEmpty) {
    return {'items': await loadProjectActivities(activeProjectId)};
  }

  final mergedItems = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  for (final projectId in normalizedProjects) {
    final projectItems = await loadProjectActivities(projectId);
    for (final raw in projectItems) {
      final id = _resolveDashboardPointId(raw);
      if (id.isNotEmpty && !seenIds.add(id)) continue;
      mergedItems.add(raw);
    }
  }

  return {'items': mergedItems};
}

List<Map<String, dynamic>> mergeDashboardMapSourceItems(
  List<Map<String, dynamic>> activities,
  List<Map<String, dynamic>> reports,
) {
  final merged = <String, Map<String, dynamic>>{};
  final anonymousItems = <Map<String, dynamic>>[];

  void upsert(Map<String, dynamic> raw) {
    final item = Map<String, dynamic>.from(raw);
    final id = _resolveDashboardPointId(item);
    if (id.isEmpty) {
      anonymousItems.add(item);
      return;
    }
    final existing = merged[id];
    if (existing == null) {
      merged[id] = item;
      return;
    }
    for (final entry in item.entries) {
      if (_isMeaningfulValue(entry.value)) {
        existing[entry.key] = entry.value;
      }
    }
  }

  for (final item in activities) {
    upsert(item);
  }
  for (final item in reports) {
    upsert(item);
  }

  return [
    ...merged.values,
    ...anonymousItems,
  ];
}

DashboardData _empty(dynamic user, DashboardRange range) => DashboardData(
      pendingCount: 0,
      approvedCount: 0,
      rejectedCount: 0,
      needsFixCount: 0,
      totalInQueue: 0,
      projectId: 'N/A',
      range: range,
      approvedTrend: const DashboardTrend(current: 0, previous: 0),
      rejectedTrend: const DashboardTrend(current: 0, previous: 0),
      needsFixTrend: const DashboardTrend(current: 0, previous: 0),
      pendingTrend: const DashboardTrend(current: 0, previous: 0),
      queueItems: const [],
      geoPoints: const [],
      topErrors: const [],
      locationCounts: const [],
      riskCounts: const {'bajo': 0, 'medio': 0, 'alto': 0, 'prioritario': 0},
      frontProgress: const [],
      avgValidationHours: 0,
    );

String _reportsQuery({
  required String projectId,
  DateTime? from,
  DateTime? to,
}) {
  final params = <String, String>{
    if (projectId.isNotEmpty) 'project_id': projectId,
    if (from != null) 'date_from': from.toUtc().toIso8601String(),
    if (to != null) 'date_to': to.toUtc().toIso8601String(),
  };
  return '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
}

String _activitiesQuery({
  required String projectId,
  int page = 1,
  int pageSize = 100,
}) {
  final normalizedPageSize = pageSize.clamp(1, 100);
  final params = <String, String>{
    if (projectId.isNotEmpty) 'project_id': projectId,
    'page': '$page',
    'page_size': '$normalizedPageSize',
  };
  return '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
}

Map<String, int> _asStringIntMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  for (final entry in raw.entries) {
    final key = entry.key.toString().trim().toUpperCase();
    final value = entry.value;
    if (key.isEmpty) continue;
    if (value is num) {
      out[key] = value.toInt();
      continue;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        out[key] = parsed;
      }
    }
  }
  return out;
}

DashboardActivityMetrics summarizeDashboardActivityMetrics(List<Map<String, dynamic>> items) {
  var total = 0;
  var pending = 0;
  var approved = 0;
  var rejected = 0;
  var needsFix = 0;

  for (final item in items) {
    if (item['deleted_at'] != null) continue;

    total += 1;
    final state = _normalizeDashboardExecutionState(item['status'] ?? item['execution_state']);
    final review = _normalizeDashboardReviewState(
      item['review_status'] ?? item['reviewStatus'] ?? item['review_decision'] ?? item['reviewDecision'],
    );

    if (review == 'REJECTED') {
      rejected += 1;
      continue;
    }
    if (review == 'CHANGES_REQUIRED') {
      needsFix += 1;
      continue;
    }
    if (review == 'APPROVED') {
      approved += 1;
      continue;
    }

    switch (state) {
      case 'COMPLETADA':
        approved += 1;
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
  }

  return DashboardActivityMetrics(
    total: total,
    pending: pending,
    approved: approved,
    rejected: rejected,
    needsFix: needsFix,
  );
}

String _normalizeDashboardExecutionState(dynamic value) {
  final normalized = (value ?? '').toString().trim().toUpperCase().replaceAll(' ', '_');
  switch (normalized) {
    case 'APPROVED':
    case 'APROBADO':
    case 'APROBADA':
      return 'COMPLETADA';
    case 'PENDING_REVIEW':
      return 'REVISION_PENDIENTE';
    case 'IN_PROGRESS':
      return 'EN_CURSO';
    case '':
      return 'PENDIENTE';
    default:
      return normalized;
  }
}

String _normalizeDashboardReviewState(dynamic value) {
  final normalized = (value ?? '').toString().trim().toUpperCase().replaceAll(' ', '_');
  switch (normalized) {
    case 'APPROVED':
    case 'APROBADO':
    case 'APROBADA':
      return 'APPROVED';
    case 'REJECTED':
    case 'RECHAZADO':
    case 'RECHAZADA':
      return 'REJECTED';
    case 'CHANGES_REQUIRED':
    case 'NECESITA_CORRECCION':
    case 'NEEDS_FIX':
      return 'CHANGES_REQUIRED';
    case 'PENDING':
    case 'PENDIENTE':
    case 'EN_REVISION':
    case 'PENDIENTE_REVISION':
      return 'PENDING_REVIEW';
    default:
      return normalized;
  }
}

List<Map<String, dynamic>> filterDashboardItemsByRange(
  List<Map<String, dynamic>> items,
  DashboardRange range,
  DateTime now,
) {
  final start = _rangeStart(now, range);
  if (start == null) return List<Map<String, dynamic>>.from(items);
  final end = now.toUtc();
  return _filterDashboardItemsByWindow(items, start, end);
}

Map<String, DashboardTrend> buildDashboardTrends(
  List<Map<String, dynamic>> items,
  DashboardRange range,
  DateTime now,
) {
  final currentItems = filterDashboardItemsByRange(items, range, now);
  final previousStart = _previousRangeStart(now, range);
  final previousEnd = _rangeStart(now, range);
  final previousItems = previousStart == null || previousEnd == null
      ? currentItems
      : _filterDashboardItemsByWindow(items, previousStart, previousEnd);

  final currentMetrics = summarizeDashboardActivityMetrics(currentItems);
  final previousMetrics = summarizeDashboardActivityMetrics(previousItems);

  return {
    'approved': DashboardTrend(current: currentMetrics.approved, previous: previousMetrics.approved),
    'pending': DashboardTrend(current: currentMetrics.pending, previous: previousMetrics.pending),
    'needsFix': DashboardTrend(current: currentMetrics.needsFix, previous: previousMetrics.needsFix),
    'rejected': DashboardTrend(current: currentMetrics.rejected, previous: previousMetrics.rejected),
  };
}

List<Map<String, dynamic>> _filterDashboardItemsByWindow(
  List<Map<String, dynamic>> items,
  DateTime start,
  DateTime end,
) {
  return items.where((item) {
    final date = _resolveDashboardItemDate(item);
    if (date == null) return false;
    final normalized = date.toUtc();
    return !normalized.isBefore(start) && normalized.isBefore(end.add(const Duration(milliseconds: 1)));
  }).toList(growable: false);
}

DateTime? _previousRangeStart(DateTime now, DashboardRange range) {
  final start = _rangeStart(now, range);
  if (start == null) return null;

  switch (range) {
    case DashboardRange.today:
      return start.subtract(const Duration(days: 1));
    case DashboardRange.week:
      return start.subtract(const Duration(days: 7));
    case DashboardRange.month:
      return DateTime.utc(start.year, start.month - 1, 1);
    case DashboardRange.all:
      return null;
  }
}

DateTime? _resolveDashboardItemDate(Map<String, dynamic> item) {
  final candidates = <dynamic>[
    item['last_reviewed_at'],
    item['reviewed_at'],
    item['updated_at'],
    item['created_at'],
    _nested(item, ['summary', 'updated_at']),
    _nested(item, ['summary', 'created_at']),
  ];

  for (final candidate in candidates) {
    final parsed = _parseDateTimeValue(candidate);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _parseDateTimeValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
  }
  return null;
}

DateTime? _rangeStart(DateTime now, DashboardRange range) {
  switch (range) {
    case DashboardRange.today:
      return DateTime.utc(now.year, now.month, now.day);
    case DashboardRange.week:
      final weekday = now.weekday;
      final start = now.subtract(Duration(days: weekday - 1));
      return DateTime.utc(start.year, start.month, start.day);
    case DashboardRange.month:
      return DateTime.utc(now.year, now.month, 1);
    case DashboardRange.all:
      return null;
  }
}

ValidationQueueItem _mapQueueItem(Map<String, dynamic> raw) {
  final risk = (raw['risk'] ?? 'bajo').toString().toLowerCase();
  final severity = (raw['severity'] ?? '').toString().toUpperCase();
  final createdAt = DateTime.tryParse((raw['created_at'] ?? '').toString()) ?? DateTime.now().toUtc();

  return ValidationQueueItem(
    id: (raw['id'] ?? '').toString(),
    projectId: (raw['project_id'] ?? 'N/A').toString(),
    userName: (raw['assigned_to_user_name'] ?? 'Sin asignar').toString(),
    activityType: (raw['activity_type'] ?? 'Actividad').toString(),
    pk: (raw['pk'] ?? '—').toString(),
    front: (raw['front'] ?? '').toString(),
    municipality: (raw['municipality'] ?? '').toString(),
    risk: severity == 'HIGH' ? 'prioritario' : risk,
    severity: severity,
    status: (raw['status'] ?? 'PENDIENTE_REVISION').toString(),
    createdAt: createdAt,
    lat: _parseDouble(raw['lat'] ?? raw['latitude']),
    lon: _parseDouble(raw['lon'] ?? raw['longitude']),
  );
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<TopErrorItem> _buildTopErrors(List<dynamic> queueItemsRaw) {
  int gps = 0;
  int missingEvidence = 0;
  int catalogChanged = 0;
  int checklistIncomplete = 0;
  int hasConflicts = 0;

  for (final raw in queueItemsRaw) {
    if (raw is! Map<String, dynamic>) continue;
    if (raw['gps_critical'] == true) gps++;
    if (raw['missing_evidence'] == true) missingEvidence++;
    if (raw['catalog_change_pending'] == true) catalogChanged++;
    if (raw['checklist_incomplete'] == true) checklistIncomplete++;
    if (raw['has_conflicts'] == true) hasConflicts++;
  }

  final result = <TopErrorItem>[
    TopErrorItem(label: 'Falta evidencia GPS/Foto', count: missingEvidence),
    TopErrorItem(label: 'Desviación GPS crítica', count: gps),
    TopErrorItem(label: 'Cambio de catálogo pendiente', count: catalogChanged),
    TopErrorItem(label: 'Checklist incompleto', count: checklistIncomplete),
    TopErrorItem(label: 'Conflictos de validación', count: hasConflicts),
  ];
  result.sort((a, b) => b.count.compareTo(a.count));
  return result;
}

String _resolveDashboardPointId(Map<String, dynamic> item) {
  final candidates = <dynamic>[
    item['id'],
    item['uuid'],
    item['server_id'],
    item['activity_id'],
    item['activityId'],
    _nested(item, ['summary', 'id']),
    _nested(item, ['summary', 'uuid']),
  ];

  for (final candidate in candidates) {
    final value = (candidate ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

DashboardGeoPoint dashboardGeoPointFromJson(
  Map<String, dynamic> item, {
  required double lat,
  required double lon,
}) {
  final rawRisk = (item['risk'] ?? item['risk_level'] ?? 'bajo').toString().trim().toLowerCase();
  final risk = switch (rawRisk) {
    'prioritario' => 'prioritario',
    'alto' => 'alto',
    'medio' => 'medio',
    _ => 'bajo',
  };
  final municipality = _resolveLocationField(item, ['municipality', 'municipio'], 'municipio');
  final state = _resolveLocationField(item, ['state', 'estado'], 'estado');
  final front = _resolveLocationField(item, ['front', 'front_name'], 'front_name');
  final title = (
    item['title'] ??
    item['activity_title'] ??
    item['activity_type'] ??
    item['activity_type_code'] ??
    _nested(item, ['wizard_payload', 'activity', 'name']) ??
    'Actividad'
  ).toString().trim();
  final hasReport = _parseBool(item['has_report']) ||
      _parseBool(item['report_generated']) ||
      _parseBool(item['is_report_generated']) ||
      (item['report_status'] ?? '').toString().trim().isNotEmpty ||
      (item['report_path'] ?? '').toString().trim().isNotEmpty ||
      (item['report_url'] ?? '').toString().trim().isNotEmpty ||
      (item['document_url'] ?? '').toString().trim().isNotEmpty;

  return DashboardGeoPoint(
    id: _resolveDashboardPointId(item),
    projectId: (item['project_id'] ?? item['projectId'] ?? '').toString().trim().toUpperCase(),
    risk: risk,
    status: (item['status'] ?? item['execution_state'] ?? '').toString(),
    reviewStatus: (item['review_status'] ?? item['reviewStatus'] ?? '').toString(),
    reviewDecision: (item['review_decision'] ?? item['reviewDecision'])?.toString(),
    front: front,
    municipality: municipality,
    state: state,
    label: title.isEmpty ? 'Actividad' : title,
    assignedToUserId: (item['assigned_to_user_id'])?.toString(),
    assignedName: (item['assigned_name'] ?? item['assigned_to_user_name'])?.toString(),
    lat: lat,
    lon: lon,
    hasReport: hasReport,
  );
}

DashboardGeoPoint? dashboardGeoPointFromMapItem(Map<String, dynamic> item) {
  final lat = _resolveCoordinateField(item, const [
    'latitude',
    'lat',
    'technicalLatitude',
    'technical_latitude',
  ], const [
    ['location', 'latitude'],
    ['location', 'lat'],
    ['location', 'latitud'],
    ['wizard_payload', 'location', 'latitude'],
    ['wizard_payload', 'location', 'lat'],
    ['wizard_payload', 'location', 'latitud'],
    ['data_fields', 'latitude'],
    ['data_fields', 'lat'],
    ['data_fields', 'latitud'],
  ]);
  final lon = _resolveCoordinateField(item, const [
    'longitude',
    'lon',
    'technicalLongitude',
    'technical_longitude',
  ], const [
    ['location', 'longitude'],
    ['location', 'lon'],
    ['location', 'longitud'],
    ['wizard_payload', 'location', 'longitude'],
    ['wizard_payload', 'location', 'lon'],
    ['wizard_payload', 'location', 'longitud'],
    ['data_fields', 'longitude'],
    ['data_fields', 'lon'],
    ['data_fields', 'longitud'],
  ]);
  if (lat == null || lon == null) return null;
  return dashboardGeoPointFromJson(item, lat: lat, lon: lon);
}

List<DashboardGeoPoint> _buildGeoPoints(List<Map<String, dynamic>> reportItems) {
  final result = <DashboardGeoPoint>[];
  for (final item in reportItems) {
    final geoPoint = dashboardGeoPointFromMapItem(item);
    if (geoPoint == null) continue;
    result.add(geoPoint);
  }
  return result;
}

List<LocationCountItem> _buildLocationCounts(List<DashboardGeoPoint> geoPoints) {
  final countByLocation = <String, int>{};
  for (final item in geoPoints) {
    final locationParts = <String>[
      if (item.municipality.trim().isNotEmpty) item.municipality.trim(),
      if (item.state.trim().isNotEmpty) item.state.trim(),
    ];
    final label = locationParts.isNotEmpty
        ? locationParts.join(' / ')
        : (item.front.trim().isNotEmpty ? item.front.trim() : 'Sin ubicacion');
    countByLocation[label] = (countByLocation[label] ?? 0) + 1;
  }

  final result = countByLocation.entries
      .map((entry) => LocationCountItem(label: entry.key, count: entry.value))
      .toList(growable: false);
  result.sort((a, b) => b.count.compareTo(a.count));
  return result;
}

Map<String, int> _buildRiskCounts(List<DashboardGeoPoint> geoPoints) {
  final result = <String, int>{'bajo': 0, 'medio': 0, 'alto': 0, 'prioritario': 0};
  for (final point in geoPoints) {
    final risk = point.risk.trim().toLowerCase();
    if (result.containsKey(risk)) {
      result[risk] = (result[risk] ?? 0) + 1;
    }
  }
  return result;
}

List<FrontProgressItem> _buildFrontProgress(List<Map<String, dynamic>> reportItems) {
  final plannedByFront = <String, int>{};
  final executedByFront = <String, int>{};

  for (final item in reportItems) {
    final resolvedFront = _resolveLocationField(item, ['front', 'front_name'], 'front_name');
    final front = resolvedFront.isEmpty ? 'Sin frente' : resolvedFront;
    plannedByFront[front] = (plannedByFront[front] ?? 0) + 1;
    if (_normalizeDashboardExecutionState(item['status'] ?? item['execution_state']) == 'COMPLETADA') {
      executedByFront[front] = (executedByFront[front] ?? 0) + 1;
    }
  }

  final result = plannedByFront.entries
      .map(
        (entry) => FrontProgressItem(
          front: entry.key,
          planned: entry.value,
          executed: executedByFront[entry.key] ?? 0,
        ),
      )
      .toList(growable: false);
  result.sort((a, b) => (b.planned - b.executed).compareTo(a.planned - a.executed));
  return result.take(6).toList(growable: false);
}

double _computeAvgValidationHours(List<Map<String, dynamic>> reportItems, DateTime now) {
  final completed = reportItems.where(
    (item) => _normalizeDashboardExecutionState(item['status'] ?? item['execution_state']) == 'COMPLETADA',
  );
  final durations = <Duration>[];
  for (final item in completed) {
    final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
    if (createdAt == null) continue;
    durations.add(now.toUtc().difference(createdAt.toUtc()));
  }
  if (durations.isEmpty) return 0;
  final totalMinutes = durations.fold<int>(0, (sum, current) => sum + current.inMinutes);
  return totalMinutes / durations.length / 60;
}

dynamic _nested(Map<String, dynamic> item, List<String> path) {
  dynamic current = item;
  for (final key in path) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 'si';
}

bool _isMeaningfulValue(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

double? _resolveCoordinateField(
  Map<String, dynamic> item,
  List<String> directKeys,
  List<List<String>> nestedPaths,
) {
  for (final key in directKeys) {
    final parsed = _parseDouble(item[key]);
    if (parsed != null) return parsed;
  }
  for (final path in nestedPaths) {
    final parsed = _parseDouble(_nested(item, path));
    if (parsed != null) return parsed;
  }
  return null;
}

String _extractTaggedValue(String text, String field) {
  final normalized = text.trim();
  if (normalized.isEmpty) return '';
  final patterns = [
    RegExp('$field\\s*[:=]\\s*([^|;,]+)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(normalized);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
  }
  return '';
}

String _resolveLocationField(
  Map<String, dynamic> item,
  List<String> directKeys,
  String wizardKey,
) {
  for (final key in directKeys) {
    final value = (item[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  final fromWizard = (_nested(item, ['wizard_payload', 'location', wizardKey]) ?? '').toString().trim();
  if (fromWizard.isNotEmpty) return fromWizard;
  final description = (item['description'] ?? '').toString();
  final fromDescription = _extractTaggedValue(description, directKeys.last);
  if (fromDescription.isNotEmpty) return fromDescription;
  return '';
}
