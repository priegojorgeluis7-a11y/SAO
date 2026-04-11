import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../features/auth/app_session_controller.dart';

enum DashboardRange { today, week, month }

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
    return approvedCount / totalInQueue;
  }
}

class DashboardGeoPoint {
  final String id;
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

  const DashboardGeoPoint({
    required this.id,
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

final selectedDashboardRangeProvider = StateProvider<DashboardRange>((_) => DashboardRange.today);

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  const client = BackendApiClient();
  final user = ref.watch(currentAppUserProvider);
  final activeProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
  final availableProjects = await ref.watch(availableProjectsProvider.future);
  final range = ref.watch(selectedDashboardRangeProvider);

  final now = DateTime.now();
  final currentStart = _rangeStart(now, range);
  final projectQuery = activeProjectId.isEmpty
      ? ''
      : '?project_id=${Uri.encodeQueryComponent(activeProjectId)}';
    final dailyTrendQuery = activeProjectId.isEmpty
      ? '?days=2'
      : '?project_id=${Uri.encodeQueryComponent(activeProjectId)}&days=2';

  try {
    final decoded = await _tryGetJsonMap(client, '/api/v1/dashboard/kpis$projectQuery');
    if (decoded == null) return _empty(user, range);

    final dailyTrendDecoded = await _tryGetJsonMap(
      client,
      '/api/v1/dashboard/kpis/daily-trend$dailyTrendQuery',
    );
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
    final visualItems = reportCurrentItems.isNotEmpty ? reportCurrentItems : activityItems;
    final trendRows = (dailyTrendDecoded?['trend'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
    final trendCurrent = trendRows.isNotEmpty ? trendRows.first : const <String, dynamic>{};
    final trendPrevious = trendRows.length > 1 ? trendRows[1] : const <String, dynamic>{};

    final pendingCount =
      (counters['review_queue_count'] as num?)?.toInt() ??
      (counters['pending_review'] as num?)?.toInt() ??
      backlogByState['REVISION_PENDIENTE'] ??
      0;
    final approvedCount =
      (counters['completed'] as num?)?.toInt() ??
      (counters['completed_today'] as num?)?.toInt() ??
      (counters['approved'] as num?)?.toInt() ??
      backlogByState['COMPLETADA'] ??
      0;
    final rejectedCount =
      (counters['overdue_review_count'] as num?)?.toInt() ??
      (queueDecoded?['counters']?['rejected'] as num?)?.toInt() ??
      0;
    final needsFixCount =
      (counters['in_progress'] as num?)?.toInt() ??
      (counters['pending_today'] as num?)?.toInt() ??
      backlogByState['EN_CURSO'] ??
      0;

    final projectId = (decoded['project_id'] ?? 'N/A').toString();

    final queueItems = queueItemsRaw
        .whereType<Map<String, dynamic>>()
        .map<ValidationQueueItem>(_mapQueueItem)
        .toList(growable: false);
    final geoPoints = _buildGeoPoints(visualItems);

    final topErrors = _buildTopErrors(queueItemsRaw);
    final locationCounts = _buildLocationCounts(geoPoints).take(8).toList(growable: false);
    final riskCounts = _buildRiskCounts(geoPoints);
    final frontProgress = _buildFrontProgress(visualItems);

    final approvedTrend = DashboardTrend(
      current: _trendInt(trendCurrent, 'completed', approvedCount),
      previous: _trendInt(trendPrevious, 'completed', 0),
    );
    final pendingTrend = DashboardTrend(
      current: _trendInt(trendCurrent, 'pending', pendingCount),
      previous: _trendInt(trendPrevious, 'pending', 0),
    );
    final needsFixTrend = DashboardTrend(
      current: needsFixCount,
      previous: _trendInt(trendPrevious, 'pending', 0),
    );
    final rejectedTrend = DashboardTrend(
      current: rejectedCount,
      previous: _trendInt(trendPrevious, 'overdue_review_count', 0),
    );

    final avgValidationHours = _computeAvgValidationHours(visualItems, now);

    return DashboardData(
      pendingCount: pendingCount,
      approvedCount: approvedCount,
      rejectedCount: rejectedCount,
      needsFixCount: needsFixCount,
        totalInQueue: (counters['total_activities'] as num?)?.toInt() ??
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
  if (activeProjectId.isNotEmpty) {
    return _tryGetJsonMap(client, '/api/v1/activities${_activitiesQuery(projectId: activeProjectId)}');
  }

  final normalizedProjects = availableProjects
      .map((projectId) => projectId.trim().toUpperCase())
      .where((projectId) => projectId.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (normalizedProjects.isEmpty) {
    return _tryGetJsonMap(client, '/api/v1/activities${_activitiesQuery(projectId: activeProjectId)}');
  }

  final mergedItems = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  for (final projectId in normalizedProjects) {
    final decoded = await _tryGetJsonMap(
      client,
      '/api/v1/activities${_activitiesQuery(projectId: projectId)}',
    );
    final items = decoded?['items'];
    if (items is! List) {
      continue;
    }
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final id = (raw['id'] ?? '').toString().trim();
      if (id.isNotEmpty && !seenIds.add(id)) {
        continue;
      }
      mergedItems.add(raw);
    }
  }

  return {'items': mergedItems};
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
  required DateTime from,
  required DateTime to,
}) {
  final params = <String, String>{
    if (projectId.isNotEmpty) 'project_id': projectId,
    'date_from': from.toUtc().toIso8601String(),
    'date_to': to.toUtc().toIso8601String(),
  };
  return '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
}

String _activitiesQuery({
  required String projectId,
}) {
  final params = <String, String>{
    if (projectId.isNotEmpty) 'project_id': projectId,
    'page_size': '100',
  };
  return '?${params.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
}

int _trendInt(Map<String, dynamic> row, String key, int fallback) {
  final value = row[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
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

DateTime _rangeStart(DateTime now, DashboardRange range) {
  switch (range) {
    case DashboardRange.today:
      return DateTime.utc(now.year, now.month, now.day);
    case DashboardRange.week:
      final weekday = now.weekday;
      final start = now.subtract(Duration(days: weekday - 1));
      return DateTime.utc(start.year, start.month, start.day);
    case DashboardRange.month:
      return DateTime.utc(now.year, now.month, 1);
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

List<DashboardGeoPoint> _buildGeoPoints(List<Map<String, dynamic>> reportItems) {
  final result = <DashboardGeoPoint>[];
  for (final item in reportItems) {
    final lat = _parseDouble(item['latitude'] ?? item['lat']);
    final lon = _parseDouble(item['longitude'] ?? item['lon']);
    if (lat == null || lon == null) continue;

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
      item['activity_type'] ??
      item['activity_type_code'] ??
      _nested(item, ['wizard_payload', 'activity', 'name']) ??
      'Actividad'
    ).toString().trim();

    result.add(
      DashboardGeoPoint(
        id: (item['id'] ?? '').toString(),
        risk: risk,
        status: (item['status'] ?? '').toString(),
        reviewStatus: (item['review_status'] ?? '').toString(),
        reviewDecision: (item['review_decision'])?.toString(),
        front: front,
        municipality: municipality,
        state: state,
        label: title.isEmpty ? 'Actividad' : title,
        assignedToUserId: (item['assigned_to_user_id'])?.toString(),
        assignedName: (item['assigned_name'] ?? item['assigned_to_user_name'])?.toString(),
        lat: lat,
        lon: lon,
      ),
    );
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
    if ((item['status'] ?? '').toString().toUpperCase() == 'COMPLETADA') {
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
  final completed = reportItems.where((item) => (item['status'] ?? '').toString().toUpperCase() == 'COMPLETADA');
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
