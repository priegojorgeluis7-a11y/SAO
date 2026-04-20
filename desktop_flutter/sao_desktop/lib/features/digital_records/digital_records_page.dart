import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/app_refresh_provider.dart';
import '../../core/providers/project_providers.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../ui/sao_ui.dart';
import '../../ui/widgets/sao_evidence_viewer.dart';
import '../auth/app_session_controller.dart';
import '../completed_activities/completed_activities_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../planning/planning_provider.dart';
import '../reports/reports_provider.dart';
import 'digital_records_colors.dart';

enum _MetricFilter {
  all,
  withDocument,
  withEvidence,
  pending,
}

void _copyRecordIdentifier(
  BuildContext context, {
  required String value,
  String label = 'PK',
}) {
  final trimmedValue = value.trim();
  if (trimmedValue.isEmpty) return;

  Clipboard.setData(ClipboardData(text: trimmedValue));
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$label copiado: $trimmedValue')),
    );
}

String _sanitizeFolderSegment(String raw, {String fallback = 'SIN_DATO'}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  final sanitized = trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (sanitized.isEmpty) return fallback;
  return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80).trim();
}

List<CompletedActivity> resolveDigitalRecordTreeItems(
  List<CompletedActivity> items, {
  String selectedProject = '',
}) {
  final sorted = List<CompletedActivity>.from(items)
    ..sort((left, right) {
      final selected = selectedProject.trim();
      if (selected.isNotEmpty) {
        final leftIsSelected = left.projectId.trim() == selected;
        final rightIsSelected = right.projectId.trim() == selected;
        if (leftIsSelected != rightIsSelected) {
          return leftIsSelected ? -1 : 1;
        }
      }

      final projectCompare = left.projectId.compareTo(right.projectId);
      if (projectCompare != 0) return projectCompare;
      final frontCompare = left.front.compareTo(right.front);
      if (frontCompare != 0) return frontCompare;
      final stateCompare = left.estado.compareTo(right.estado);
      if (stateCompare != 0) return stateCompare;
      final municipalityCompare = left.municipio.compareTo(right.municipio);
      if (municipalityCompare != 0) return municipalityCompare;
      return left.title.compareTo(right.title);
    });

  return sorted;
}

Future<File> _manualActivityLinksFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/manual_activity_links.json');
}

Future<Map<String, dynamic>> _readManualActivityLinksRegistry() async {
  final file = await _manualActivityLinksFile();
  if (!await file.exists()) {
    return <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return <String, dynamic>{};
  }
  return <String, dynamic>{};
}

Future<List<ManualRelatedLink>> _readManualRelatedLinks(
    String activityId) async {
  final registry = await _readManualActivityLinksRegistry();
  return ManualRelatedLink.normalizeList(
    registry[activityId],
    currentId: activityId,
  );
}

Future<void> _writeManualRelatedLinks({
  required String activityId,
  required List<ManualRelatedLink> relatedLinks,
}) async {
  final file = await _manualActivityLinksFile();
  final registry = await _readManualActivityLinksRegistry();

  final normalized = ManualRelatedLink.normalizeList(
    relatedLinks.map((item) => item.toJson()).toList(growable: false),
    currentId: activityId,
  );
  final previous = _readableLinkMap(
    ManualRelatedLink.normalizeList(registry[activityId],
        currentId: activityId),
  );

  registry[activityId] =
      normalized.map((item) => item.toJson()).toList(growable: false);

  final normalizedIds = normalized.map((item) => item.activityId).toSet();
  for (final removedId
      in previous.keys.where((id) => !normalizedIds.contains(id))) {
    final existing = ManualRelatedLink.normalizeList(
      registry[removedId],
      currentId: removedId,
    )
        .where((item) => item.activityId != activityId)
        .map((item) => item.toJson())
        .toList(growable: false);
    registry[removedId] = existing;
  }

  for (final link in normalized) {
    final existing = ManualRelatedLink.normalizeList(
      registry[link.activityId],
      currentId: link.activityId,
    ).where((item) => item.activityId != activityId).toList(growable: true);
    existing.add(link.copyWith(activityId: activityId));
    registry[link.activityId] =
        existing.map((item) => item.toJson()).toList(growable: false);
  }

  await file.writeAsString(jsonEncode(registry), flush: true);
}

Map<String, ManualRelatedLink> _readableLinkMap(List<ManualRelatedLink> links) {
  return {
    for (final item in links) item.activityId: item,
  };
}

Future<bool> _openPath({
  required String path,
  bool openParentDirectory = false,
}) async {
  final targetPath = openParentDirectory ? File(path).parent.path : path;
  final uri = Uri.file(targetPath);

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return true;
  } catch (_) {
    // Fall back to native desktop commands below.
  }

  try {
    late final ProcessResult result;
    if (Platform.isMacOS) {
      result = await Process.run('open', [targetPath]);
    } else if (Platform.isWindows) {
      result = await Process.run('cmd', ['/c', 'start', '', targetPath]);
    } else {
      result = await Process.run('xdg-open', [targetPath]);
    }
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<String> _resolveUserDocumentsRootPath() async {
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

bool _isPdfLikeEvidence(EvidenceItem evidence) {
  final typeToken = evidence.type.trim().toUpperCase();
  final gcsToken = evidence.gcsPath.trim().toLowerCase();
  return typeToken.contains('PDF') ||
      typeToken.contains('DOCUMENT') ||
      gcsToken.endsWith('.pdf');
}

EvidenceItem? _selectLatestPdfEvidence(List<EvidenceItem> evidences) {
  final pdfEvidences =
      evidences.where(_isPdfLikeEvidence).toList(growable: false);
  if (pdfEvidences.isEmpty) return null;

  pdfEvidences.sort((left, right) {
    final leftDate = DateTime.tryParse(left.uploadedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = DateTime.tryParse(right.uploadedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  });
  return pdfEvidences.first;
}

List<EvidenceItem> _documentEvidencesFor(CompletedActivityDetail detail) {
  final merged = <EvidenceItem>[];
  final seen = <String>{};

  void appendUnique(EvidenceItem evidence) {
    final key = '${evidence.id}|${evidence.gcsPath}|${evidence.uploadedAt}';
    if (seen.add(key)) {
      merged.add(evidence);
    }
  }

  for (final evidence in detail.documents) {
    appendUnique(evidence);
  }
  for (final evidence in detail.evidences.where(_isPdfLikeEvidence)) {
    appendUnique(evidence);
  }

  return merged;
}

List<EvidenceItem> _visualEvidencesFor(CompletedActivityDetail detail) {
  return detail.evidences
      .where((evidence) => !_isPdfLikeEvidence(evidence))
      .toList(growable: false);
}

int _visualEvidenceCountFor(CompletedActivityDetail detail) {
  final visualCount = _visualEvidencesFor(detail).length;
  if (detail.evidences.isNotEmpty || detail.documents.isNotEmpty) {
    return visualCount;
  }
  return detail.summary.evidenceCount;
}

int _summaryDocumentCount(CompletedActivity summary) {
  if (summary.documentCount > 0) return summary.documentCount;
  return summary.hasReport ? 1 : 0;
}

int _documentCountForDetail(CompletedActivityDetail detail) {
  final documentCount = _documentEvidencesFor(detail).length;
  if (documentCount > 0) return documentCount;
  return _summaryDocumentCount(detail.summary);
}

String _documentCountLabel(int count) {
  return count == 1 ? '1 documento' : '$count documentos';
}

String _inferredReportFileName(
    CompletedActivityDetail detail, EvidenceItem evidence) {
  final summary = detail.summary;
  final activityDate = DateTime.tryParse(summary.createdAt) ??
      DateTime.tryParse(summary.reviewedAt) ??
      DateTime.tryParse(evidence.uploadedAt) ??
      DateTime.now();
  final dateToken = DateFormat('yyyyMMdd').format(activityDate);
  final projectToken =
      _sanitizeFolderSegment(summary.projectId, fallback: 'GENERAL');
  final frontToken =
      _sanitizeFolderSegment(summary.front, fallback: 'SIN_FRENTE');
  final stateToken =
      _sanitizeFolderSegment(summary.estado, fallback: 'SIN_ESTADO');
  final activityToken =
      _sanitizeFolderSegment(summary.activityType, fallback: 'ACTIVIDAD');
  return '${projectToken}_${frontToken}_${stateToken}_${activityToken}_$dateToken.pdf';
}

Future<File> _downloadReportPdfForDetail(
  CompletedActivityDetail detail,
  EvidenceItem evidence,
) async {
  final signedUrl =
      await EvidenceRepository().getDownloadSignedUrl(evidence.id);
  final uri = Uri.parse(signedUrl);
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('No se pudo descargar PDF (${response.statusCode})');
    }

    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    if (bytes.isEmpty) {
      throw const FileSystemException('El PDF descargado llegó vacío');
    }

    final docsRootPath = await _resolveUserDocumentsRootPath();
    final projectFolder =
        _sanitizeFolderSegment(detail.summary.projectId, fallback: 'GENERAL');
    final frontFolder =
        _sanitizeFolderSegment(detail.summary.front, fallback: 'SIN_FRENTE');
    final stateFolder =
        _sanitizeFolderSegment(detail.summary.estado, fallback: 'SIN_ESTADO');
    final municipalityFolder = _sanitizeFolderSegment(detail.summary.municipio,
        fallback: 'SIN_MUNICIPIO');
    final activityFolder = _sanitizeFolderSegment(detail.summary.activityType,
        fallback: 'ACTIVIDAD');
    final expedienteFolder =
        _sanitizeFolderSegment(detail.summary.id, fallback: 'SIN_ID');
    final activityDir = Directory(
      '$docsRootPath/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/Reportes',
    );
    if (!await activityDir.exists()) {
      await activityDir.create(recursive: true);
    }

    final file = File(
        '${activityDir.path}/${_inferredReportFileName(detail, evidence)}');
    await file.writeAsBytes(bytes, flush: true);

    await registerDownloadedReportReference(
      activityId: detail.summary.id,
      file: file,
      sourceEvidenceId: evidence.id,
      generatedAt: evidence.uploadedAt,
    );

    return file;
  } finally {
    client.close(force: true);
  }
}

bool _canDeleteFromDigitalRecord(AppUser? user, {String? projectId}) {
  if (user == null) return false;
  return user.hasPermission('activity.delete', projectId: projectId);
}

bool _canManageActivityLinks(AppUser? user) {
  if (user == null) return false;
  final normalizedRoles = <String>{
    user.role.trim().toUpperCase(),
    ...user.roles.map((role) => role.trim().toUpperCase()),
  }..removeWhere((value) => value.isEmpty);
  return normalizedRoles.any(
    (role) =>
        const {'ADMIN', 'COORD', 'SUPERVISOR', 'OPERATIVO'}.contains(role),
  );
}

String _relationTypeLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'antecedente':
      return 'Antecedente';
    case 'misma_problematica':
      return 'Misma problemática';
    case 'escalamiento':
      return 'Escalamiento';
    case 'complemento_documental':
      return 'Complemento documental';
    default:
      return 'Seguimiento';
  }
}

String _followUpStatusLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'en_seguimiento':
      return 'En seguimiento';
    case 'resuelta':
      return 'Resuelta';
    case 'bloqueada':
      return 'Bloqueada';
    default:
      return 'Abierta';
  }
}

Color _followUpStatusColor(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'resuelta':
      return SaoColors.success;
    case 'bloqueada':
      return SaoColors.error;
    case 'en_seguimiento':
      return SaoColors.warning;
    default:
      return DigitalRecordColors.accent;
  }
}

class DigitalRecordFollowUpSummary {
  final int relatedCount;
  final String latestStatus;

  const DigitalRecordFollowUpSummary({
    required this.relatedCount,
    required this.latestStatus,
  });

  bool get hasRelatedActivities => relatedCount > 0;
}

DigitalRecordFollowUpSummary resolveDigitalRecordFollowUpSummary({
  List<String> relatedActivityIds = const <String>[],
  List<ManualRelatedLink> relatedLinks = const <ManualRelatedLink>[],
}) {
  final normalizedLinks = ManualRelatedLink.normalizeList(
    relatedLinks.map((item) => item.toJson()).toList(growable: false),
  );
  final uniqueIds = <String>{
    ...relatedActivityIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
    ...normalizedLinks
        .map((item) => item.activityId.trim())
        .where((item) => item.isNotEmpty),
  };

  ManualRelatedLink? latestLink;
  var latestDate = DateTime.fromMillisecondsSinceEpoch(0);
  for (final link in normalizedLinks) {
    final candidateDate =
        DateTime.tryParse(link.createdAt) ??
        DateTime.tryParse(link.dueDate) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    if (latestLink == null || candidateDate.isAfter(latestDate)) {
      latestLink = link;
      latestDate = candidateDate;
    }
  }

  final normalizedStatus = latestLink?.status.trim().toLowerCase() ?? '';
  return DigitalRecordFollowUpSummary(
    relatedCount: uniqueIds.length,
    latestStatus:
        normalizedStatus.isEmpty ? 'sin_seguimiento' : normalizedStatus,
  );
}

String digitalRecordFollowUpStatusLabel(String raw) {
  if (raw.trim().toLowerCase() == 'sin_seguimiento') {
    return 'Sin seguimiento';
  }
  return _followUpStatusLabel(raw);
}

String _cleanDigitalRecordUserName(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return '';
  final words = trimmed.split(' ');
  return words
      .map((word) {
        if (word.isEmpty) return word;
        final lower = word.toLowerCase();
        if (word == lower) {
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        }
        return word;
      })
      .join(' ');
}

List<String> resolveDigitalRecordUserOptions({
  List<String> backendUsers = const <String>[],
  List<CompletedActivity> items = const <CompletedActivity>[],
}) {
  final byKey = <String, String>{};

  void addCandidate(String raw) {
    final cleaned = _cleanDigitalRecordUserName(raw);
    if (cleaned.isEmpty) return;
    final key = cleaned.toLowerCase();
    final existing = byKey[key];
    if (existing == null || existing == existing.toLowerCase()) {
      byKey[key] = cleaned;
    }
  }

  for (final user in backendUsers) {
    addCandidate(user);
  }
  for (final item in items) {
    addCandidate(item.assignedName);
  }

  final values = byKey.values.toList()
    ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return <String>['Todo', ...values];
}

final manualActivityLinksRegistryProvider =
    FutureProvider.autoDispose<Map<String, List<ManualRelatedLink>>>((ref) async {
  final registry = await _readManualActivityLinksRegistry();
  final normalized = <String, List<ManualRelatedLink>>{};
  registry.forEach((key, value) {
    final activityId = key.trim();
    if (activityId.isEmpty) return;
    normalized[activityId] =
        ManualRelatedLink.normalizeList(value, currentId: activityId);
  });
  return normalized;
});

class DigitalRecordsPage extends ConsumerStatefulWidget {
  const DigitalRecordsPage({super.key});

  @override
  ConsumerState<DigitalRecordsPage> createState() => _DigitalRecordsPageState();
}

class _DigitalRecordsPageState extends ConsumerState<DigitalRecordsPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedActivityId;
  _MetricFilter _activeMetricFilter = _MetricFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(completedSearchQueryProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeProject = ref.read(activeProjectIdProvider);
      final selectedProject = ref.read(completedProjectFilterProvider);
      if (selectedProject.isEmpty && activeProject.isNotEmpty) {
        ref.read(completedProjectFilterProvider.notifier).state = activeProject;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    ref.read(completedSearchQueryProvider.notifier).state =
        _searchController.text.trim();
  }

  void _resetFilters() {
    _searchController.clear();
    ref.read(completedProjectFilterProvider.notifier).state = '';
    ref.read(completedFrenteFilterProvider.notifier).state = '';
    ref.read(completedTemaFilterProvider.notifier).state = '';
    ref.read(completedEstadoFilterProvider.notifier).state = '';
    ref.read(completedMunicipioFilterProvider.notifier).state = '';
    ref.read(completedUsuarioFilterProvider.notifier).state = '';
    ref.read(completedSearchQueryProvider.notifier).state = '';
  }

  void _ensureSelection(List<CompletedActivity> items,
      {String? preferredActivityId}) {
    if (items.isEmpty) {
      if (_selectedActivityId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedActivityId = null);
        });
      }
      return;
    }

    final preferredId = preferredActivityId?.trim();
    if (preferredId != null && preferredId.isNotEmpty) {
      final match =
          items.where((item) => item.id == preferredId).toList(growable: false);
      if (match.isNotEmpty && _selectedActivityId != preferredId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedActivityId = preferredId);
        });
        return;
      }
    }

    final alreadySelected = _selectedActivityId != null &&
        items.any((item) => item.id == _selectedActivityId);
    if (alreadySelected) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedActivityId = items.first.id);
    });
  }

  List<CompletedActivity> _applyMetricFilter(List<CompletedActivity> items) {
    switch (_activeMetricFilter) {
      case _MetricFilter.all:
        return items;
      case _MetricFilter.withDocument:
        return items
            .where((item) => _summaryDocumentCount(item) > 0)
            .toList(growable: false);
      case _MetricFilter.withEvidence:
        return items
            .where((item) => item.evidenceCount > 0)
            .toList(growable: false);
      case _MetricFilter.pending:
        return items
            .where((item) =>
                _summaryDocumentCount(item) == 0 || item.evidenceCount == 0)
            .toList(growable: false);
    }
  }

  void _toggleMetricFilter(_MetricFilter metric) {
    setState(() {
      _activeMetricFilter =
          _activeMetricFilter == metric ? _MetricFilter.all : metric;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedItemsAsync = ref.watch(completedActivitiesProvider);
    final explorerItemsAsync = ref.watch(completedExplorerActivitiesProvider);
    final projectsAsync = ref.watch(availableProjectsProvider);
    final filterOptionsAsync = ref.watch(completedFilterOptionsProvider);
    final focusedActivityId = ref.watch(operationsHubActivityIdProvider);

    final selectedProject = ref.watch(completedProjectFilterProvider);
    final selectedFront = ref.watch(completedFrenteFilterProvider);
    final selectedState = ref.watch(completedEstadoFilterProvider);
    final selectedUser = ref.watch(completedUsuarioFilterProvider);
    final treeItems = resolveDigitalRecordTreeItems(
      explorerItemsAsync.maybeWhen(
        data: (items) => items,
        orElse: () => const <CompletedActivity>[],
      ),
      selectedProject: selectedProject,
    );

    return Scaffold(
      backgroundColor: DigitalRecordColors.scaffoldFor(context),
      body: Column(
        children: [
          _Header(
            itemsAsync: completedItemsAsync,
            onRefresh: () {
              ref.invalidate(completedActivitiesProvider);
              ref.invalidate(completedExplorerActivitiesProvider);
            },
            activeMetricFilter: _activeMetricFilter,
            onMetricSelected: _toggleMetricFilter,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 320,
                    child: _FiltersPanel(
                      searchController: _searchController,
                      projectsAsync: projectsAsync,
                      filterOptionsAsync: filterOptionsAsync,
                      items: treeItems,
                      selectedProject: selectedProject,
                      selectedFront: selectedFront,
                      selectedState: selectedState,
                      selectedUser: selectedUser,
                      onApplySearch: _applySearch,
                      onReset: _resetFilters,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: completedItemsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => SaoPanel(
                        title: 'Expedientes',
                        child: SaoEmptyState(
                          icon: Icons.folder_off_rounded,
                          message: 'No se pudieron cargar los expedientes',
                          subtitle: '$error',
                        ),
                      ),
                      data: (items) {
                        final filteredItems = _applyMetricFilter(items);
                        _ensureSelection(filteredItems,
                            preferredActivityId: focusedActivityId);
                        return _RecordsList(
                          items: filteredItems,
                          selectedActivityId: _selectedActivityId,
                          onSelect: (item) =>
                              setState(() => _selectedActivityId = item.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: _DetailPanel(
                      activityId: _selectedActivityId,
                      onDeleted: (deletedId) {
                        if (!mounted) return;
                        setState(() {
                          if (_selectedActivityId == deletedId) {
                            _selectedActivityId = null;
                          }
                        });
                      },
                      onOpenLinkedActivity: (linkedId) {
                        if (!mounted) return;
                        setState(() => _selectedActivityId = linkedId);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.itemsAsync,
    required this.onRefresh,
    required this.activeMetricFilter,
    required this.onMetricSelected,
  });

  final AsyncValue<List<CompletedActivity>> itemsAsync;
  final VoidCallback onRefresh;
  final _MetricFilter activeMetricFilter;
  final ValueChanged<_MetricFilter> onMetricSelected;

  @override
  Widget build(BuildContext context) {
    final metrics = itemsAsync.maybeWhen(
      data: (items) => _HeaderMetrics.fromItems(items),
      orElse: _HeaderMetrics.empty,
    );

    return Container(
      width: double.infinity,
      color: DigitalRecordColors.headerSurfaceFor(context),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DigitalRecordColors.accentSurfaceFor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_copy_rounded,
                  color: DigitalRecordColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expediente digital',
                        style: SaoTypography.pageTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Consulta y opera expedientes desde una sola vista con filtros, checklist documental, evidencias y trazabilidad.',
                      style: SaoTypography.bodyText.copyWith(
                        color: SaoColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                label: 'Expedientes',
                value: '${metrics.records}',
                isActive: activeMetricFilter == _MetricFilter.all,
                onTap: () => onMetricSelected(_MetricFilter.all),
              ),
              _MetricCard(
                label: 'Con reporte',
                value: '${metrics.withDocument}',
                isActive: activeMetricFilter == _MetricFilter.withDocument,
                onTap: () => onMetricSelected(_MetricFilter.withDocument),
              ),
              _MetricCard(
                label: 'Con evidencia',
                value: '${metrics.withEvidence}',
                isActive: activeMetricFilter == _MetricFilter.withEvidence,
                onTap: () => onMetricSelected(_MetricFilter.withEvidence),
              ),
              _MetricCard(
                label: 'Pendientes',
                value: '${metrics.pending}',
                isActive: activeMetricFilter == _MetricFilter.pending,
                onTap: () => onMetricSelected(_MetricFilter.pending),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetrics {
  const _HeaderMetrics({
    required this.records,
    required this.withDocument,
    required this.withEvidence,
    required this.pending,
  });

  final int records;
  final int withDocument;
  final int withEvidence;
  final int pending;

  factory _HeaderMetrics.fromItems(List<CompletedActivity> items) {
    return _HeaderMetrics(
      records: items.length,
      withDocument:
          items.where((item) => _summaryDocumentCount(item) > 0).length,
      withEvidence: items.where((item) => item.evidenceCount > 0).length,
      pending: items
          .where((item) =>
              _summaryDocumentCount(item) == 0 || item.evidenceCount == 0)
          .length,
    );
  }

  factory _HeaderMetrics.empty() => const _HeaderMetrics(
        records: 0,
        withDocument: 0,
        withEvidence: 0,
        pending: 0,
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isActive ? 'Quitar filtro' : 'Filtrar por $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 170,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? DigitalRecordColors.accentSurfaceFor(context)
                  : DigitalRecordColors.mutedSurfaceFor(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? DigitalRecordColors.accent.withValues(alpha: 0.45)
                    : DigitalRecordColors.borderFor(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: SaoTypography.sectionTitle
                      .copyWith(color: DigitalRecordColors.accent),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.textMutedFor(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  isActive ? 'Filtro activo' : 'Clic para filtrar',
                  style: SaoTypography.caption.copyWith(
                    color: isActive
                        ? DigitalRecordColors.accent
                        : SaoColors.textMutedFor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersPanel extends ConsumerWidget {
  const _FiltersPanel({
    required this.searchController,
    required this.projectsAsync,
    required this.filterOptionsAsync,
    required this.items,
    required this.selectedProject,
    required this.selectedFront,
    required this.selectedState,
    required this.selectedUser,
    required this.onApplySearch,
    required this.onReset,
  });

  final TextEditingController searchController;
  final AsyncValue<List<String>> projectsAsync;
  final AsyncValue<FilterOptions> filterOptionsAsync;
  final List<CompletedActivity> items;
  final String selectedProject;
  final String selectedFront;
  final String selectedState;
  final String selectedUser;
  final VoidCallback onApplySearch;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = filterOptionsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const FilterOptions.empty(),
    );
    final projects = projectsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <String>[],
    );
    final userOptions = resolveDigitalRecordUserOptions(
      backendUsers: filters.usuarios,
      items: items,
    );
    final selectedUserValue =
        selectedUser.trim().isEmpty ? 'Todo' : _cleanDigitalRecordUserName(selectedUser);

    return SaoPanel(
      title: 'Carpetas SAO',
      subtitle: 'Explora la ruta del expediente como árbol de carpetas.',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ExplorerBreadcrumb(
              project: selectedProject,
              front: selectedFront,
              state: selectedState,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              onSubmitted: (_) => onApplySearch(),
              decoration: InputDecoration(
                hintText: 'Buscar dentro de la carpeta actual',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: onApplySearch,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: userOptions.contains(selectedUserValue)
                  ? selectedUserValue
                  : 'Todo',
              decoration: InputDecoration(
                labelText: 'Usuario que realizó',
                prefixIcon: const Icon(Icons.person_search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: userOptions
                  .map(
                    (user) => DropdownMenuItem<String>(
                      value: user,
                      child: Text(user),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                ref.read(completedUsuarioFilterProvider.notifier).state =
                    value == null || value == 'Todo' ? '' : value;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DigitalRecordColors.panelSurfaceFor(context),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: DigitalRecordColors.borderFor(context)),
              ),
              child: _FolderTreeExplorer(
                projects: projects,
                fronts: filters.frentes,
                states: filters.estados,
                items: items,
                selectedProject: selectedProject,
                selectedFront: selectedFront,
                selectedState: selectedState,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.drive_file_move_rtl_rounded),
              label: const Text('Volver a raíz'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplorerBreadcrumb extends StatelessWidget {
  const _ExplorerBreadcrumb({
    required this.project,
    required this.front,
    required this.state,
  });

  final String project;
  final String front;
  final String state;

  @override
  Widget build(BuildContext context) {
    final segments = <String>[
      project.isEmpty ? 'Proyectos' : project,
      front.isEmpty ? 'Frentes' : front,
      state.isEmpty ? 'Estados' : state,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DigitalRecordColors.panelSurfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DigitalRecordColors.borderFor(context)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_zip_rounded,
            size: 16,
            color: DigitalRecordColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < segments.length; index++) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: index == segments.length - 1
                          ? DigitalRecordColors.accentSurfaceFor(context)
                          : DigitalRecordColors.mutedSurfaceFor(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      segments[index],
                      style: SaoTypography.caption.copyWith(
                        color: index == segments.length - 1
                            ? DigitalRecordColors.accent
                            : SaoColors.textFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (index < segments.length - 1)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: SaoColors.gray400,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTreeExplorer extends ConsumerWidget {
  const _FolderTreeExplorer({
    required this.projects,
    required this.fronts,
    required this.states,
    required this.items,
    required this.selectedProject,
    required this.selectedFront,
    required this.selectedState,
  });

  final List<String> projects;
  final List<String> fronts;
  final List<String> states;
  final List<CompletedActivity> items;
  final String selectedProject;
  final String selectedFront;
  final String selectedState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String normalizedProject(CompletedActivity item) {
      final value = item.projectId.trim();
      return value.isEmpty ? 'SIN_PROYECTO' : value;
    }

    String normalizedFront(CompletedActivity item) {
      final value = item.front.trim();
      return value.isEmpty ? 'Sin frente' : value;
    }

    String normalizedState(CompletedActivity item) {
      final value = item.estado.trim();
      return value.isEmpty ? 'Sin estado' : value;
    }

    final derivedProjects = items.map(normalizedProject).toSet();
    final configuredProjects = projects
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final sortedProjects = <String>{
      ...configuredProjects,
      ...derivedProjects,
      if (selectedProject.trim().isNotEmpty) selectedProject.trim(),
    }.toList()
      ..sort();

    List<String> frontsForProject(String project) {
      final derived = items
          .where((item) => normalizedProject(item) == project)
          .map(normalizedFront)
          .toSet()
          .toList()
        ..sort();
      if (derived.isNotEmpty) return derived;
      return fronts.where((item) => item.trim().isNotEmpty).toSet().toList()
        ..sort();
    }

    List<String> statesForFront(String project, String front) {
      final derived = items
          .where((item) =>
              normalizedProject(item) == project &&
              normalizedFront(item) == front)
          .map(normalizedState)
          .toSet()
          .toList()
        ..sort();
      if (derived.isNotEmpty) return derived;
      return states.where((item) => item.trim().isNotEmpty).toSet().toList()
        ..sort();
    }

    int activityCountForProject(String project) {
      return items.where((item) => normalizedProject(item) == project).length;
    }

    int reportCountForProject(String project) {
      return items
          .where((item) =>
              normalizedProject(item) == project &&
              _summaryDocumentCount(item) > 0)
          .length;
    }

    int activityCountForFront(String project, String front) {
      return items
          .where(
            (item) =>
                normalizedProject(item) == project &&
                normalizedFront(item) == front,
          )
          .length;
    }

    int reportCountForFront(String project, String front) {
      return items
          .where(
            (item) =>
                normalizedProject(item) == project &&
                normalizedFront(item) == front &&
                _summaryDocumentCount(item) > 0,
          )
          .length;
    }

    int activityCountForState(String project, String front, String state) {
      return items
          .where(
            (item) =>
                normalizedProject(item) == project &&
                normalizedFront(item) == front &&
                normalizedState(item) == state,
          )
          .length;
    }

    int reportCountForState(String project, String front, String state) {
      return items
          .where(
            (item) =>
                normalizedProject(item) == project &&
                normalizedFront(item) == front &&
                normalizedState(item) == state &&
                _summaryDocumentCount(item) > 0,
          )
          .length;
    }

    if (sortedProjects.isEmpty) {
      return Text(
        'No hay carpetas disponibles.',
        style: SaoTypography.caption.copyWith(
          color: SaoColors.textMutedFor(context),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final project in sortedProjects) ...[
          _ExplorerNode(
            label: project,
            icon: Icons.business_outlined,
            level: 0,
            reportCount: reportCountForProject(project),
            activityCount: activityCountForProject(project),
            isExpanded: project == selectedProject,
            isSelected: project == selectedProject,
            accent: project == selectedProject,
            onTap: () {
              ref.read(completedProjectFilterProvider.notifier).state = project;
              ref.read(completedFrenteFilterProvider.notifier).state = '';
              ref.read(completedEstadoFilterProvider.notifier).state = '';
            },
          ),
          if (project == selectedProject)
            for (final front in frontsForProject(project)) ...[
              _ExplorerNode(
                label: front,
                icon: Icons.description_outlined,
                level: 1,
                reportCount: reportCountForFront(project, front),
                activityCount: activityCountForFront(project, front),
                isExpanded: front == selectedFront,
                isSelected: front == selectedFront,
                accent: front == selectedFront,
                onTap: () {
                  ref.read(completedProjectFilterProvider.notifier).state =
                      project;
                  ref.read(completedFrenteFilterProvider.notifier).state =
                      front;
                  ref.read(completedEstadoFilterProvider.notifier).state = '';
                },
              ),
              if (front == selectedFront)
                for (final state in statesForFront(project, front))
                  _ExplorerNode(
                    label: state,
                    icon: Icons.folder_outlined,
                    level: 2,
                    reportCount: reportCountForState(project, front, state),
                    activityCount: activityCountForState(project, front, state),
                    isExpanded: false,
                    isSelected: state == selectedState,
                    accent: state == selectedState,
                    onTap: () {
                      ref.read(completedProjectFilterProvider.notifier).state =
                          project;
                      ref.read(completedFrenteFilterProvider.notifier).state =
                          front;
                      ref.read(completedEstadoFilterProvider.notifier).state =
                          state == selectedState ? '' : state;
                    },
                  ),
            ],
        ],
      ],
    );
  }
}

class _ExplorerNode extends StatelessWidget {
  const _ExplorerNode({
    required this.label,
    required this.icon,
    required this.level,
    required this.reportCount,
    required this.activityCount,
    required this.isExpanded,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int level;
  final int reportCount;
  final int activityCount;
  final bool isExpanded;
  final bool isSelected;
  final bool accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final leftInset = level * 28.0;

    return Padding(
      padding: EdgeInsets.only(left: leftInset, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? DigitalRecordColors.accentSurfaceFor(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: level < 2
                    ? Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: SaoColors.textMutedFor(context),
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.transparent,
                      ),
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 19,
                color: level == 2
                    ? const Color(0xFFF59E0B)
                    : accent
                        ? DigitalRecordColors.accent
                        : SaoColors.textMutedFor(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: SaoTypography.bodyText.copyWith(
                        color: accent
                            ? DigitalRecordColors.accent
                            : SaoColors.textFor(context),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: level == 0 ? 15 : 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reportCount <= 0
                          ? 'Sin reporte'
                          : reportCount == 1
                              ? '1 reporte'
                              : '$reportCount reportes',
                      style: SaoTypography.caption.copyWith(
                        color: accent
                            ? DigitalRecordColors.accent
                            : SaoColors.textMutedFor(context),
                        fontWeight:
                            reportCount > 0 ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DigitalRecordColors.accent.withValues(alpha: 0.12)
                      : DigitalRecordColors.mutedSurfaceFor(context),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? DigitalRecordColors.accent.withValues(alpha: 0.32)
                        : DigitalRecordColors.borderFor(context),
                  ),
                ),
                child: Text(
                  '$activityCount',
                  style: SaoTypography.caption.copyWith(
                    color: accent
                        ? DigitalRecordColors.accent
                        : SaoColors.textFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.items,
    required this.selectedActivityId,
    required this.onSelect,
  });

  final List<CompletedActivity> items;
  final String? selectedActivityId;
  final ValueChanged<CompletedActivity> onSelect;

  @override
  Widget build(BuildContext context) {
    return SaoPanel(
      title: 'Expedientes',
      subtitle: items.isEmpty
          ? 'Sin resultados'
          : '${items.length} expedientes disponibles',
      child: items.isEmpty
          ? const SizedBox(
              height: 420,
              child: SaoEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'No hay expedientes para los filtros seleccionados',
                subtitle:
                    'Ajusta la búsqueda o limpia los filtros para consultar más resultados.',
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _RecordRow(
                      item: items[index],
                      isSelected: items[index].id == selectedActivityId,
                      onTap: () => onSelect(items[index]),
                    ),
                    if (index < items.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RecordRow extends ConsumerWidget {
  const _RecordRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final CompletedActivity item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _visualStatusFor(item);
    final pkValue = item.pk.trim();
    final localRelatedLinks = ref.watch(manualActivityLinksRegistryProvider)
        .maybeWhen(
          data: (registry) => registry[item.id] ?? const <ManualRelatedLink>[],
          orElse: () => const <ManualRelatedLink>[],
        );
    final followUpSummary = resolveDigitalRecordFollowUpSummary(
      relatedActivityIds:
          localRelatedLinks.map((link) => link.activityId).toList(growable: false),
      relatedLinks: localRelatedLinks,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? DigitalRecordColors.selectedSurfaceFor(context)
              : DigitalRecordColors.mutedSurfaceFor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? DigitalRecordColors.selectedBorderFor(context)
                : DigitalRecordColors.borderFor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title.trim().isEmpty ? item.activityType : item.title,
                    style: SaoTypography.bodyTextBold,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(label: status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pkValue.isEmpty)
                  const _MetaChip(
                      icon: Icons.badge_outlined, label: 'Sin folio')
                else
                  _CopyablePkChip(
                    value: pkValue,
                    onTap: () => _copyRecordIdentifier(context, value: pkValue),
                  ),
                _MetaChip(
                    icon: Icons.folder_open_rounded,
                    label: item.front.isEmpty ? 'Sin frente' : item.front),
                _MetaChip(
                    icon: Icons.map_outlined,
                    label: item.estado.isEmpty ? 'Sin estado' : item.estado),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.projectId} · ${item.assignedName.isEmpty ? 'Sin responsable' : item.assignedName}',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.textMutedFor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(item.createdAt),
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.textMutedFor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatPill(
                    icon: Icons.image_outlined,
                    label: '${item.evidenceCount} evidencias'),
                _StatPill(
                  icon: Icons.description_outlined,
                  label: _summaryDocumentCount(item) <= 0
                      ? 'Sin reporte'
                      : _summaryDocumentCount(item) == 1
                          ? '1 reporte'
                          : '${_summaryDocumentCount(item)} reportes',
                ),
                _FollowUpChip(
                  icon: followUpSummary.hasRelatedActivities
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  label: followUpSummary.hasRelatedActivities
                      ? (followUpSummary.relatedCount == 1
                          ? '1 relacionada'
                          : '${followUpSummary.relatedCount} relacionadas')
                      : 'Sin relacionadas',
                  color: followUpSummary.hasRelatedActivities
                      ? DigitalRecordColors.accent
                      : SaoColors.textMutedFor(context),
                ),
                _FollowUpChip(
                  icon: Icons.track_changes_rounded,
                  label:
                      'Seguimiento: ${digitalRecordFollowUpStatusLabel(followUpSummary.latestStatus)}',
                  color: followUpSummary.latestStatus == 'sin_seguimiento'
                      ? SaoColors.textMutedFor(context)
                      : _followUpStatusColor(followUpSummary.latestStatus),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({
    required this.activityId,
    required this.onDeleted,
    required this.onOpenLinkedActivity,
  });

  final String? activityId;
  final ValueChanged<String> onDeleted;
  final ValueChanged<String> onOpenLinkedActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activityId == null || activityId!.isEmpty) {
      return const SaoPanel(
        title: 'Detalle',
        child: SizedBox(
          height: 420,
          child: SaoEmptyState(
            icon: Icons.fact_check_outlined,
            message: 'Selecciona un expediente',
            subtitle:
                'Aquí verás resumen, checklist, documentos, evidencias y auditoría.',
          ),
        ),
      );
    }

    final detailAsync = ref.watch(completedActivityDetailProvider(activityId!));

    return detailAsync.when(
      loading: () => const SaoPanel(
        title: 'Detalle del expediente',
        child: SizedBox(
          height: 420,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => SaoPanel(
        title: 'Detalle del expediente',
        child: SizedBox(
          height: 420,
          child: SaoEmptyState(
            icon: Icons.error_outline_rounded,
            message: 'No se pudo cargar el detalle',
            subtitle: '$error',
          ),
        ),
      ),
      data: (detail) {
        Future<void> handleChecklistDocumentOpen() async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          try {
            final reference =
                await findGeneratedReportReference(detail.summary.id);
            if (reference != null && await File(reference.filePath).exists()) {
              final opened = await _openPath(path: reference.filePath);
              messenger?.hideCurrentSnackBar();
              if (!opened) {
                messenger?.showSnackBar(
                  const SnackBar(
                      content: Text('No se pudo abrir el PDF local.')),
                );
                return;
              }
              messenger?.showSnackBar(
                const SnackBar(content: Text('Abriendo PDF local.')),
              );
              return;
            }

            final remotePdfEvidence = _selectLatestPdfEvidence(
              _documentEvidencesFor(detail),
            );
            if (!detail.summary.hasReport || remotePdfEvidence == null) {
              messenger?.hideCurrentSnackBar();
              messenger?.showSnackBar(
                const SnackBar(
                    content:
                        Text('No hay un documento disponible para abrir.')),
              );
              return;
            }

            if (!context.mounted) return;
            final shouldDownload = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Descargar documento'),
                content: const Text(
                  'Este equipo no tiene una copia local del PDF. ¿Deseas descargarlo y abrirlo ahora?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Descargar'),
                  ),
                ],
              ),
            );
            if (shouldDownload != true) return;

            final file =
                await _downloadReportPdfForDetail(detail, remotePdfEvidence);
            final opened = await _openPath(path: file.path);
            messenger?.hideCurrentSnackBar();
            if (!opened) {
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text(
                      'El PDF se descargó, pero no se pudo abrir automáticamente.'),
                ),
              );
              return;
            }
            messenger?.showSnackBar(
              const SnackBar(content: Text('PDF descargado y abierto.')),
            );
          } catch (error) {
            messenger?.hideCurrentSnackBar();
            messenger?.showSnackBar(
              SnackBar(content: Text('No se pudo abrir el documento: $error')),
            );
          }
        }

        final checklist = _buildChecklist(
          detail,
          onOpenDocument: handleChecklistDocumentOpen,
        );
        final completion = checklist.where((item) => item.done).length;
        final completionPercent = checklist.isEmpty
            ? 0
            : ((completion / checklist.length) * 100).round();
        final pkValue = detail.summary.pk.trim();
        final currentUser = ref.watch(currentAppUserProvider);
        final canDelete = _canDeleteFromDigitalRecord(
          currentUser,
          projectId: detail.summary.projectId,
        );
        final canManageLinks = _canManageActivityLinks(currentUser);
        final allActivities = ref.watch(completedActivitiesProvider).maybeWhen(
              data: (items) => items,
              orElse: () => const <CompletedActivity>[],
            );

        Future<void> handleDelete() async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Eliminar actividad'),
              content: const Text(
                'Esta acción eliminará la actividad del expediente y quedará registrada en auditoría. ¿Deseas continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: SaoColors.error),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;

          try {
            await ref
                .read(activityRepositoryProvider)
                .deleteActivity(activityId!);
            onDeleted(activityId!);
            ref.invalidate(completedActivitiesProvider);
            ref.invalidate(completedExplorerActivitiesProvider);
            ref.invalidate(completedFilterOptionsProvider);
            ref.invalidate(completedActivityDetailProvider(activityId!));
            ref.invalidate(planningAssignmentsProvider);
            ref.invalidate(planningMonthlyAssignmentsProvider);
            ref.invalidate(reportActivitiesProvider);
            ref.invalidate(dashboardProvider);
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Actividad eliminada desde Expediente'),
                  backgroundColor: SaoColors.success,
                ),
              );
          } catch (error) {
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.maybeOf(context);
            messenger
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('No se pudo eliminar la actividad: $error'),
                  backgroundColor: SaoColors.error,
                ),
              );
          }
        }

        return SaoPanel(
          title: 'Detalle del expediente',
          subtitle: pkValue.isEmpty ? detail.summary.id : null,
          trailing: pkValue.isEmpty
              ? null
              : _CopyablePkChip(
                  value: pkValue,
                  onTap: () => _copyRecordIdentifier(context, value: pkValue),
                ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailHero(
                    detail: detail, completionPercent: completionPercent),
                if (canDelete) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: handleDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Eliminar actividad'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SaoColors.error,
                        side: const BorderSide(color: SaoColors.error),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Checklist de cumplimiento',
                  child: Column(
                    children: checklist
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ChecklistRow(item: item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Historial relacionado manualmente',
                  child: _RelatedHistorySection(
                    detail: detail,
                    activities: allActivities,
                    canManageLinks: canManageLinks,
                    onOpenActivity: onOpenLinkedActivity,
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title:
                      'Documentos · ${_documentCountLabel(_documentCountForDetail(detail))}',
                  child: _DocumentsSection(detail: detail),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                    title: 'Evidencias',
                    child: _EvidenceSection(detail: detail)),
                const SizedBox(height: 16),
                _SectionCard(
                    title: 'Bitácora y auditoría',
                    child: _AuditSection(detail: detail)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailHero extends ConsumerWidget {
  const _DetailHero({required this.detail, required this.completionPercent});

  final CompletedActivityDetail detail;
  final int completionPercent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = detail.summary;
    final localRelatedLinks = ref.watch(manualActivityLinksRegistryProvider)
        .maybeWhen(
          data: (registry) =>
              registry[detail.summary.id] ?? const <ManualRelatedLink>[],
          orElse: () => const <ManualRelatedLink>[],
        );
    final followUpSummary = resolveDigitalRecordFollowUpSummary(
      relatedActivityIds: <String>[
        ...detail.relatedActivityIds,
        ...localRelatedLinks.map((link) => link.activityId),
      ],
      relatedLinks: <ManualRelatedLink>[
        ...detail.relatedLinks,
        ...localRelatedLinks,
      ],
    );
    final pkValue = summary.pk.trim();
    final locationLabel = detail.colonia.isEmpty
        ? (summary.municipio.isEmpty
            ? 'Ubicación pendiente'
            : summary.municipio)
        : '${summary.municipio} · ${detail.colonia}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DigitalRecordColors.mutedSurfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DigitalRecordColors.borderFor(context)),
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
                    Text(
                      summary.title.trim().isEmpty
                          ? summary.activityType
                          : summary.title,
                      style: SaoTypography.sectionTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.projectId} · ${summary.front.isEmpty ? 'Sin frente' : summary.front} · ${summary.estado.isEmpty ? 'Sin estado' : summary.estado}',
                      style: SaoTypography.bodyText.copyWith(
                        color: SaoColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(label: _visualStatusFor(summary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: completionPercent / 100,
                  minHeight: 8,
                  backgroundColor:
                      DigitalRecordColors.progressTrackFor(context),
                  color: DigitalRecordColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Text('$completionPercent%', style: SaoTypography.bodyTextBold),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pkValue.isEmpty)
                const _MetaChip(icon: Icons.badge_outlined, label: 'Sin folio')
              else
                _CopyablePkChip(
                  value: pkValue,
                  onTap: () => _copyRecordIdentifier(context, value: pkValue),
                ),
              _MetaChip(
                icon: Icons.person_outline_rounded,
                label: summary.assignedName.isEmpty
                    ? 'Sin responsable'
                    : summary.assignedName,
              ),
              _MetaChip(
                  icon: Icons.location_city_outlined, label: locationLabel),
              _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: _formatDate(summary.createdAt)),
              _FollowUpChip(
                icon: followUpSummary.hasRelatedActivities
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                label: followUpSummary.hasRelatedActivities
                    ? (followUpSummary.relatedCount == 1
                        ? '1 actividad relacionada'
                        : '${followUpSummary.relatedCount} actividades relacionadas')
                    : 'Sin actividades relacionadas',
                color: followUpSummary.hasRelatedActivities
                    ? DigitalRecordColors.accent
                    : SaoColors.textMutedFor(context),
              ),
              _FollowUpChip(
                icon: Icons.track_changes_rounded,
                label:
                    'Último seguimiento: ${digitalRecordFollowUpStatusLabel(followUpSummary.latestStatus)}',
                color: followUpSummary.latestStatus == 'sin_seguimiento'
                    ? SaoColors.textMutedFor(context)
                    : _followUpStatusColor(followUpSummary.latestStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelatedHistorySection extends ConsumerStatefulWidget {
  const _RelatedHistorySection({
    required this.detail,
    required this.activities,
    required this.canManageLinks,
    required this.onOpenActivity,
  });

  final CompletedActivityDetail detail;
  final List<CompletedActivity> activities;
  final bool canManageLinks;
  final ValueChanged<String> onOpenActivity;

  @override
  ConsumerState<_RelatedHistorySection> createState() =>
      _RelatedHistorySectionState();
}

class _RelatedHistorySectionState
    extends ConsumerState<_RelatedHistorySection> {
  String? _selectedActivityId;
  String _selectedRelationType = 'seguimiento';
  String _selectedStatus = 'abierta';
  bool _saving = false;
  DateTime? _dueDate;
  List<ManualRelatedLink> _localLinks = const <ManualRelatedLink>[];
  late final TextEditingController _reasonController;
  late final TextEditingController _nextActionController;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _nextActionController = TextEditingController();
    _loadLocalLinks();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _nextActionController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RelatedHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.summary.id != widget.detail.summary.id) {
      _resetForm();
      _loadLocalLinks();
    }
  }

  void _resetForm() {
    _selectedActivityId = null;
    _selectedRelationType = 'seguimiento';
    _selectedStatus = 'abierta';
    _dueDate = null;
    _reasonController.clear();
    _nextActionController.clear();
  }

  Future<void> _pickDueDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'MX'),
    );
    if (selected != null && mounted) {
      setState(() => _dueDate = selected);
    }
  }

  Future<void> _loadLocalLinks() async {
    try {
      final links = await _readManualRelatedLinks(widget.detail.summary.id);
      if (mounted) {
        setState(() => _localLinks = links);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _localLinks = const <ManualRelatedLink>[]);
      }
    }
  }

  Future<void> _persistLinks(
    List<ManualRelatedLink> nextLinks, {
    required String successMessage,
  }) async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final normalizedNextLinks = ManualRelatedLink.normalizeList(
      nextLinks.map((item) => item.toJson()).toList(growable: false),
      currentId: widget.detail.summary.id,
    );

    setState(() => _saving = true);
    try {
      await _writeManualRelatedLinks(
        activityId: widget.detail.summary.id,
        relatedLinks: normalizedNextLinks,
      );
      ref.invalidate(manualActivityLinksRegistryProvider);
      try {
        await saveRelatedActivityLinks(
          activityId: widget.detail.summary.id,
          relatedLinks: normalizedNextLinks,
        );
      } catch (_) {
        // El guardado local mantiene el seguimiento operativo incluso si el
        // backend no está actualizado todavía.
      }
      ref.invalidate(
        completedActivityDetailProvider(widget.detail.summary.id),
      );
      ref.invalidate(completedActivitiesProvider);
      ref.invalidate(completedExplorerActivitiesProvider);
      await _loadLocalLinks();
      if (mounted) {
        setState(_resetForm);
      }
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo guardar el vínculo: $error')),
        );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentAppUserProvider);
    final effectiveLinks = ManualRelatedLink.normalizeList(
      [
        ...widget.detail.relatedLinks.map((item) => item.toJson()),
        ..._localLinks.map((item) => item.toJson()),
      ],
      currentId: widget.detail.summary.id,
    );
    final effectiveRelatedIds =
        effectiveLinks.map((item) => item.activityId).toList(growable: false);
    final linkById = _readableLinkMap(effectiveLinks);
    final linkedActivities = resolveManualRelatedActivities(
      current: widget.detail.summary,
      relatedActivityIds: effectiveRelatedIds,
      candidates: widget.activities,
    );
    final linkedIds = effectiveRelatedIds.toSet();
    final availableActivities = widget.activities
        .where(
          (item) =>
              item.id != widget.detail.summary.id &&
              !linkedIds.contains(item.id),
        )
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final unresolvedIds = effectiveRelatedIds
        .where((id) => linkedActivities.every((item) => item.id != id))
        .toList(growable: false);
    final canSubmit = _selectedActivityId != null &&
        !_saving &&
        _nextActionController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.canManageLinks
              ? 'Ahora puedes ligar con seguimiento real: motivo, estado, próxima acción y fecha compromiso.'
              : 'Estas actividades fueron ligadas manualmente para conservar el historial del mismo asunto.',
          style: SaoTypography.bodyText.copyWith(
            color: SaoColors.textMutedFor(context),
          ),
        ),
        if (widget.canManageLinks) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DigitalRecordColors.mutedSurfaceFor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DigitalRecordColors.borderFor(context)),
            ),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedActivityId,
                  decoration: InputDecoration(
                    labelText: 'Ligar con otra actividad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  items: availableActivities
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            '${item.title.trim().isEmpty ? item.activityType : item.title} · ${item.pk.trim().isEmpty ? item.id : item.pk}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: availableActivities.isEmpty || _saving
                      ? null
                      : (value) => setState(() => _selectedActivityId = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRelationType,
                        decoration: InputDecoration(
                          labelText: 'Tipo de relación',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'seguimiento', child: Text('Seguimiento')),
                          DropdownMenuItem(
                              value: 'antecedente', child: Text('Antecedente')),
                          DropdownMenuItem(
                              value: 'misma_problematica',
                              child: Text('Misma problemática')),
                          DropdownMenuItem(
                              value: 'escalamiento',
                              child: Text('Escalamiento')),
                          DropdownMenuItem(
                              value: 'complemento_documental',
                              child: Text('Complemento documental')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() =>
                                _selectedRelationType = value ?? 'seguimiento'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Estado del seguimiento',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'abierta', child: Text('Abierta')),
                          DropdownMenuItem(
                              value: 'en_seguimiento',
                              child: Text('En seguimiento')),
                          DropdownMenuItem(
                              value: 'resuelta', child: Text('Resuelta')),
                          DropdownMenuItem(
                              value: 'bloqueada', child: Text('Bloqueada')),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _selectedStatus = value ?? 'abierta'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  enabled: !_saving,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Motivo o contexto',
                    hintText: 'Ej. continuidad del mismo caso social',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nextActionController,
                  enabled: !_saving,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Próxima acción',
                    hintText: 'Ej. llamada, visita o reunión pendiente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDueDate,
                      icon: const Icon(Icons.event_available_rounded, size: 16),
                      label: Text(
                        _dueDate == null
                            ? 'Fecha compromiso'
                            : DateFormat('dd/MM/yyyy').format(_dueDate!),
                      ),
                    ),
                    if (_dueDate != null)
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Quitar fecha'),
                      ),
                    FilledButton.icon(
                      onPressed: canSubmit
                          ? () => _persistLinks(
                                [
                                  ...effectiveLinks,
                                  ManualRelatedLink(
                                    activityId: _selectedActivityId!,
                                    relationType: _selectedRelationType,
                                    status: _selectedStatus,
                                    reason: _reasonController.text.trim(),
                                    nextAction:
                                        _nextActionController.text.trim(),
                                    dueDate: _dueDate?.toIso8601String() ?? '',
                                    createdAt: DateTime.now().toIso8601String(),
                                    createdBy: currentUser?.fullName
                                                .trim()
                                                .isNotEmpty ==
                                            true
                                        ? currentUser!.fullName.trim()
                                        : (currentUser?.email ?? ''),
                                  ),
                                ],
                                successMessage:
                                    'Actividad ligada con seguimiento guardado.',
                              )
                          : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_rounded, size: 16),
                      label: Text(_saving ? 'Guardando...' : 'Vincular'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (linkedActivities.isEmpty && unresolvedIds.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DigitalRecordColors.mutedSurfaceFor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DigitalRecordColors.borderFor(context)),
            ),
            child: Text(
              'Sin actividades ligadas manualmente todavía.',
              style: SaoTypography.bodyText.copyWith(
                color: SaoColors.textMutedFor(context),
              ),
            ),
          )
        else ...[
          for (var index = 0; index < linkedActivities.length; index++) ...[
            _ManualRelatedHistoryCard(
              item: linkedActivities[index],
              link: linkById[linkedActivities[index].id],
              canRemove: widget.canManageLinks,
              onOpen: () => widget.onOpenActivity(linkedActivities[index].id),
              onRemove: () => _persistLinks(
                effectiveLinks
                    .where(
                        (item) => item.activityId != linkedActivities[index].id)
                    .toList(growable: false),
                successMessage: 'Vínculo eliminado del historial.',
              ),
            ),
            if (index < linkedActivities.length - 1 || unresolvedIds.isNotEmpty)
              const SizedBox(height: 10),
          ],
          for (var index = 0; index < unresolvedIds.length; index++) ...[
            _ManualRelatedHistoryCard(
              item: null,
              unresolvedId: unresolvedIds[index],
              link: linkById[unresolvedIds[index]],
              canRemove: widget.canManageLinks,
              onOpen: () => widget.onOpenActivity(unresolvedIds[index]),
              onRemove: () => _persistLinks(
                effectiveLinks
                    .where((item) => item.activityId != unresolvedIds[index])
                    .toList(growable: false),
                successMessage: 'Vínculo eliminado del historial.',
              ),
            ),
            if (index < unresolvedIds.length - 1) const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _ManualRelatedHistoryCard extends StatelessWidget {
  const _ManualRelatedHistoryCard({
    this.item,
    this.unresolvedId,
    this.link,
    required this.canRemove,
    required this.onOpen,
    required this.onRemove,
  });

  final CompletedActivity? item;
  final String? unresolvedId;
  final ManualRelatedLink? link;
  final bool canRemove;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = item == null
        ? 'Actividad ligada'
        : (item!.title.trim().isEmpty ? item!.activityType : item!.title);
    final subtitle = item == null
        ? (unresolvedId ?? 'Sin referencia')
        : '${item!.projectId} · ${item!.front.isEmpty ? 'Sin frente' : item!.front} · ${_formatDate(item!.createdAt)}';
    final chipLabel = item?.pk.trim().isNotEmpty == true
        ? item!.pk.trim()
        : (unresolvedId ?? 'Vínculo manual');
    final statusColor = _followUpStatusColor(link?.status ?? 'abierta');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DigitalRecordColors.mutedSurfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DigitalRecordColors.borderFor(context)),
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
                    Text(
                      title,
                      style: SaoTypography.bodyTextBold,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir'),
                  ),
                  if (canRemove)
                    OutlinedButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: const Text('Quitar'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HistoryReasonChip(label: chipLabel),
              _HistoryReasonChip(
                label: _relationTypeLabel(link?.relationType ?? 'seguimiento'),
              ),
              _HistoryReasonChip(
                label: _followUpStatusLabel(link?.status ?? 'abierta'),
                backgroundColor: statusColor.withValues(alpha: 0.14),
                textColor: statusColor,
              ),
            ],
          ),
          if (link != null &&
              (link!.reason.isNotEmpty ||
                  link!.nextAction.isNotEmpty ||
                  link!.dueDate.isNotEmpty ||
                  link!.createdBy.isNotEmpty)) ...[
            const SizedBox(height: 10),
            if (link!.reason.isNotEmpty)
              Text(
                'Motivo: ${link!.reason}',
                style: SaoTypography.caption,
              ),
            if (link!.nextAction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Próxima acción: ${link!.nextAction}',
                  style: SaoTypography.caption,
                ),
              ),
            if (link!.dueDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Fecha compromiso: ${_formatDate(link!.dueDate)}',
                  style: SaoTypography.caption,
                ),
              ),
            if (link!.createdBy.isNotEmpty || link!.createdAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ligó: ${link!.createdBy.isEmpty ? 'Equipo operativo' : link!.createdBy}${link!.createdAt.isEmpty ? '' : ' · ${_formatDate(link!.createdAt)}'}',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.textMutedFor(context),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryReasonChip extends StatelessWidget {
  const _HistoryReasonChip({
    required this.label,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? DigitalRecordColors.accentSurfaceFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SaoTypography.caption.copyWith(
          color: textColor ?? DigitalRecordColors.accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FollowUpChip extends StatelessWidget {
  const _FollowUpChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: SaoTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends ConsumerStatefulWidget {
  const _DocumentsSection({required this.detail});

  final CompletedActivityDetail detail;

  @override
  ConsumerState<_DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends ConsumerState<_DocumentsSection> {
  bool _downloading = false;

  bool _isLikelyPdfEvidence(EvidenceItem evidence) {
    final typeToken = evidence.type.trim().toUpperCase();
    final gcsToken = evidence.gcsPath.trim().toLowerCase();
    return typeToken.contains('PDF') ||
        typeToken.contains('DOCUMENT') ||
        gcsToken.endsWith('.pdf');
  }

  EvidenceItem? _selectPdfEvidence(List<EvidenceItem> evidences) {
    final pdfEvidences =
        evidences.where(_isLikelyPdfEvidence).toList(growable: false);
    if (pdfEvidences.isEmpty) return null;

    pdfEvidences.sort((left, right) {
      final leftDate = DateTime.tryParse(left.uploadedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate = DateTime.tryParse(right.uploadedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
    return pdfEvidences.first;
  }

  String _inferredFileName(
      CompletedActivityDetail detail, EvidenceItem evidence) {
    final summary = detail.summary;
    final activityDate = DateTime.tryParse(summary.createdAt) ??
        DateTime.tryParse(summary.reviewedAt) ??
        DateTime.tryParse(evidence.uploadedAt) ??
        DateTime.now();
    final dateToken = DateFormat('yyyyMMdd').format(activityDate);
    final projectToken =
        _sanitizeFolderSegment(summary.projectId, fallback: 'GENERAL');
    final frontToken =
        _sanitizeFolderSegment(summary.front, fallback: 'SIN_FRENTE');
    final stateToken =
        _sanitizeFolderSegment(summary.estado, fallback: 'SIN_ESTADO');
    final activityToken =
        _sanitizeFolderSegment(summary.activityType, fallback: 'ACTIVIDAD');
    return '${projectToken}_${frontToken}_${stateToken}_${activityToken}_$dateToken.pdf';
  }

  Future<File> _downloadEvidencePdf(
    CompletedActivityDetail detail,
    EvidenceItem evidence,
  ) async {
    final signedUrl =
        await EvidenceRepository().getDownloadSignedUrl(evidence.id);
    final uri = Uri.parse(signedUrl);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'No se pudo descargar PDF (${response.statusCode})');
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty) {
        throw const FileSystemException('El PDF descargado llegó vacío');
      }

      final docsRootPath = await _resolveUserDocumentsRootPath();
      final projectFolder =
          _sanitizeFolderSegment(detail.summary.projectId, fallback: 'GENERAL');
      final frontFolder =
          _sanitizeFolderSegment(detail.summary.front, fallback: 'SIN_FRENTE');
      final stateFolder =
          _sanitizeFolderSegment(detail.summary.estado, fallback: 'SIN_ESTADO');
      final municipalityFolder = _sanitizeFolderSegment(
          detail.summary.municipio,
          fallback: 'SIN_MUNICIPIO');
      final activityFolder = _sanitizeFolderSegment(detail.summary.activityType,
          fallback: 'ACTIVIDAD');
      final expedienteFolder =
          _sanitizeFolderSegment(detail.summary.id, fallback: 'SIN_ID');
      final activityDir = Directory(
        '$docsRootPath/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/Reportes',
      );
      if (!await activityDir.exists()) {
        await activityDir.create(recursive: true);
      }

      final file =
          File('${activityDir.path}/${_inferredFileName(detail, evidence)}');
      await file.writeAsBytes(bytes, flush: true);

      await registerDownloadedReportReference(
        activityId: detail.summary.id,
        file: file,
        sourceEvidenceId: evidence.id,
        generatedAt: evidence.uploadedAt,
      );

      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadAndOpen(
    CompletedActivityDetail detail,
    EvidenceItem evidence,
  ) async {
    if (_downloading) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _downloading = true);
    try {
      final file = await _downloadEvidencePdf(detail, evidence);
      if (!await _openPath(path: file.path)) {
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el PDF descargado')),
          );
        return;
      }
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('PDF descargado en: ${file.path}')),
        );
    } catch (error) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo descargar el PDF: $error')),
        );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.detail.summary;
    if (!summary.hasReport) {
      return const SaoEmptyState(
        icon: Icons.description_outlined,
        message: 'No hay documento oficial generado',
        subtitle: 'El expediente todavía no marca reporte generado.',
      );
    }

    final currentUser = ref.watch(currentAppUserProvider);

    return FutureBuilder<String?>(
      future: findExistingLocalReportPath(
        activityId: summary.id,
        projectId: summary.projectId,
        front: summary.front,
        state: summary.estado,
        municipality: summary.municipio,
        activityType: summary.activityType,
      ),
      builder: (context, snapshot) {
        final localPdfPath = snapshot.data;
        final hasLocalPdf =
            localPdfPath != null && localPdfPath.trim().isNotEmpty;
        final documentEvidences = _documentEvidencesFor(widget.detail);
        final remotePdfEvidence = _selectPdfEvidence(documentEvidences);
        final bool canDownloadFromCloud =
            !hasLocalPdf && remotePdfEvidence != null;

        final generatedReference = hasLocalPdf
            ? GeneratedReportReference(
                activityId: summary.id,
                filePath: localPdfPath,
                generatedAt: summary.reviewedAt,
              )
            : null;
        final reference = generatedReference;

        final uploadedByLabel = remotePdfEvidence?.uploaderName.trim() ?? '';
        final likelyCurrentUserReport = currentUser != null &&
            uploadedByLabel.isNotEmpty &&
            (uploadedByLabel.toLowerCase() ==
                    currentUser.fullName.trim().toLowerCase() ||
                uploadedByLabel.toLowerCase() ==
                    currentUser.email.trim().toLowerCase());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InfoRow(
                label: 'Documento', value: 'Reporte operativo generado'),
            _InfoRow(
              label: 'Estado',
              value: reference == null
                  ? 'Generado, sin PDF local vinculado'
                  : 'Disponible para abrir desde expediente',
            ),
            _InfoRow(
                label: 'Fecha de revisión',
                value: _formatDate(summary.reviewedAt)),
            _InfoRow(
              label: 'Revisó',
              value: summary.reviewedByName.isEmpty
                  ? 'No disponible'
                  : summary.reviewedByName,
            ),
            if (reference != null) ...[
              _InfoRow(label: 'Archivo', value: reference.fileName),
              if (reference.generatedAt.isNotEmpty)
                _InfoRow(
                    label: 'Generado',
                    value: _formatDate(reference.generatedAt)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final opened = await _openPath(path: reference.filePath);
                      if (!opened) {
                        messenger
                          ?..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                                content: Text('No se pudo abrir el PDF')),
                          );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Abrir PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final opened = await _openPath(
                        path: reference.filePath,
                        openParentDirectory: true,
                      );
                      if (!opened) {
                        messenger
                          ?..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                                content: Text('No se pudo abrir la carpeta')),
                          );
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Abrir carpeta'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                canDownloadFromCloud
                    ? 'Este equipo no tiene copia local. Puedes descargar el PDF desde la nube y quedará cacheado para aperturas futuras.'
                    : 'El expediente ya marca documento generado, pero este equipo aún no tiene una ruta local del PDF. Vuelve a generar el PDF desde Reportes en esta máquina para vincularlo aquí.',
                style: SaoTypography.caption.copyWith(
                  color: SaoColors.textMutedFor(context),
                ),
              ),
              if (canDownloadFromCloud) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _downloading
                          ? null
                          : () => _downloadAndOpen(
                              widget.detail, remotePdfEvidence),
                      icon: _downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                          _downloading ? 'Descargando...' : 'Descargar PDF'),
                    ),
                    if (likelyCurrentUserReport)
                      const Text(
                        'Tip: si este PDF lo generaste tú en este equipo, se abrirá siempre en local sin descarga.',
                      ),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _EvidenceSection extends ConsumerStatefulWidget {
  const _EvidenceSection({required this.detail});

  final CompletedActivityDetail detail;

  @override
  ConsumerState<_EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends ConsumerState<_EvidenceSection> {
  String? _downloadingEvidenceId;
  final Map<String, Future<String>> _previewSourceCache = {};

  String _captionFor(EvidenceItem evidence) {
    final caption = evidence.description.trim();
    return caption.isEmpty ? 'Sin pie de foto' : caption;
  }

  bool _isPreviewableImage(EvidenceItem evidence) {
    final typeToken = evidence.type.trim().toUpperCase();
    final gcsToken = evidence.gcsPath.trim().toLowerCase();
    final looksLikeVideo = typeToken.contains('VIDEO') ||
        gcsToken.endsWith('.mp4') ||
        gcsToken.endsWith('.mov');
    return !looksLikeVideo && !_isLikelyPdfEvidence(evidence);
  }

  bool _isRemoteSource(String source) {
    final normalized = source.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  Directory _buildTargetDirectory(EvidenceItem evidence) {
    final summary = widget.detail.summary;
    final docsRootPath = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    final baseRoot = docsRootPath != null && docsRootPath.trim().isNotEmpty
        ? '$docsRootPath/Documents'
        : '';
    final projectFolder =
        _sanitizeFolderSegment(summary.projectId, fallback: 'GENERAL');
    final frontFolder =
        _sanitizeFolderSegment(summary.front, fallback: 'SIN_FRENTE');
    final stateFolder =
        _sanitizeFolderSegment(summary.estado, fallback: 'SIN_ESTADO');
    final municipalityFolder =
        _sanitizeFolderSegment(summary.municipio, fallback: 'SIN_MUNICIPIO');
    final activityFolder =
        _sanitizeFolderSegment(summary.activityType, fallback: 'ACTIVIDAD');
    final expedienteFolder =
        _sanitizeFolderSegment(summary.id, fallback: 'SIN_ID');
    final folderName = _isLikelyPdfEvidence(evidence) ? 'pdfs' : 'evidencias';
    return Directory(
      '$baseRoot/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/$folderName',
    );
  }

  String _buildEvidenceFilePrefix(EvidenceItem evidence) {
    final summary = widget.detail.summary;
    final pkToken = _safeSegment(summary.pk.isEmpty ? summary.id : summary.pk,
        fallback: 'actividad');
    final descToken = _safeSegment(
      evidence.description.isEmpty ? evidence.type : evidence.description,
    );
    final shortId = evidence.id
        .substring(0, evidence.id.length > 8 ? 8 : evidence.id.length);
    return '${pkToken}_${descToken}_$shortId';
  }

  Future<File?> _findCachedEvidenceFile(EvidenceItem evidence) async {
    final targetDir = _buildTargetDirectory(evidence);
    if (!await targetDir.exists()) return null;

    final prefix = _buildEvidenceFilePrefix(evidence);
    await for (final entity in targetDir.list(followLinks: false)) {
      if (entity is File) {
        final fileName = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (fileName.startsWith(prefix) && await entity.exists()) {
          _previewSourceCache[evidence.id] = Future<String>.value(entity.path);
          return entity;
        }
      }
    }
    return null;
  }

  Future<String> _previewSourceFor(EvidenceItem evidence) {
    return _previewSourceCache.putIfAbsent(
      evidence.id,
      () async {
        final cached = await _findCachedEvidenceFile(evidence);
        if (cached != null) return cached.path;
        return EvidenceRepository().getDownloadSignedUrl(evidence.id);
      },
    );
  }

  Widget _buildPreviewThumbnail(String source) {
    if (_isRemoteSource(source)) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.image_outlined,
            color: DigitalRecordColors.accent,
          ),
        ),
      );
    }

    final file = source.startsWith('file://')
        ? File(Uri.parse(source).toFilePath())
        : File(source);
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(
          Icons.image_outlined,
          color: DigitalRecordColors.accent,
        ),
      ),
    );
  }

  Future<void> _showPreview(EvidenceItem evidence) async {
    if (!_isPreviewableImage(evidence)) {
      await _downloadAndOpen(evidence);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 920,
            height: 680,
            child: FutureBuilder<String>(
              future: _previewSourceFor(evidence),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.trim().isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_outlined, size: 56),
                        const SizedBox(height: 12),
                        const Text(
                          'No se pudo cargar la vista previa de la evidencia.',
                          style: SaoTypography.bodyTextBold,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _captionFor(evidence),
                          style: SaoTypography.bodyText,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                _previewSourceCache.remove(evidence.id);
                                Navigator.of(dialogContext).pop();
                                _showPreview(evidence);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                _downloadAndOpen(evidence);
                              },
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Descargar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vista previa',
                                    style: SaoTypography.sectionTitle),
                                const SizedBox(height: 4),
                                Text(
                                  _captionFor(evidence),
                                  style: SaoTypography.caption.copyWith(
                                    color: SaoColors.textMutedFor(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SaoEvidenceViewer(
                        imageUrl: snapshot.data!,
                        caption: _captionFor(evidence),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  bool _isLikelyPdfEvidence(EvidenceItem evidence) {
    final typeToken = evidence.type.trim().toUpperCase();
    final gcsToken = evidence.gcsPath.trim().toLowerCase();
    return typeToken.contains('PDF') ||
        typeToken.contains('DOCUMENT') ||
        gcsToken.endsWith('.pdf');
  }

  String _extractExtension(String raw) {
    final sanitized = raw.trim().toLowerCase();
    final match = RegExp(r'\.(jpg|jpeg|png|pdf|mp4|mov|heic|webp)(?:\?|$)')
        .firstMatch(sanitized);
    return match != null ? '.${match.group(1)!}' : '';
  }

  String _guessExtension(EvidenceItem evidence, String signedUrl) {
    final fromPath = _extractExtension(evidence.gcsPath);
    if (fromPath.isNotEmpty) return fromPath;

    final fromUrl = _extractExtension(signedUrl);
    if (fromUrl.isNotEmpty) return fromUrl;

    final typeToken = evidence.type.trim().toUpperCase();
    if (typeToken.contains('PDF') || typeToken.contains('DOCUMENT')) {
      return '.pdf';
    }
    if (typeToken.contains('VIDEO')) {
      return '.mp4';
    }
    return '.jpg';
  }

  String _safeSegment(String raw, {String fallback = 'evidencia'}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return fallback;
    final sanitized = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    if (sanitized.isEmpty) return fallback;
    return sanitized.length <= 60 ? sanitized : sanitized.substring(0, 60);
  }

  Future<File> _downloadEvidenceFile(EvidenceItem evidence) async {
    final cached = await _findCachedEvidenceFile(evidence);
    if (cached != null) {
      return cached;
    }

    final signedUrl =
        await EvidenceRepository().getDownloadSignedUrl(evidence.id);
    final uri = Uri.parse(signedUrl);
    final client = HttpClient();

    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'No se pudo descargar la evidencia (${response.statusCode})');
      }

      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty) {
        throw const FileSystemException('La evidencia descargada llegó vacía');
      }

      final targetDir = _buildTargetDirectory(evidence);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final ext = _guessExtension(evidence, signedUrl);
      final file =
          File('${targetDir.path}/${_buildEvidenceFilePrefix(evidence)}$ext');
      await file.writeAsBytes(bytes, flush: true);
      _previewSourceCache[evidence.id] = Future<String>.value(file.path);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadAndOpen(EvidenceItem evidence) async {
    if (_downloadingEvidenceId != null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _downloadingEvidenceId = evidence.id);

    try {
      final file = await _downloadEvidenceFile(evidence);
      if (!await _openPath(path: file.path)) {
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
                content: Text('No se pudo abrir la evidencia descargada')),
          );
        return;
      }
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Evidencia descargada en: ${file.path}')),
        );
    } catch (error) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No se pudo descargar la evidencia: $error')),
        );
    } finally {
      if (mounted) {
        setState(() => _downloadingEvidenceId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final visibleEvidences = _visualEvidencesFor(detail);
    if (visibleEvidences.isEmpty) {
      return const SaoEmptyState(
        icon: Icons.perm_media_outlined,
        message: 'No hay evidencias fotográficas cargadas',
        subtitle:
            'Aquí solo se muestran fotos o evidencias reales capturadas en campo.',
      );
    }

    return Column(
      children: visibleEvidences
          .map(
            (evidence) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DigitalRecordColors.mutedSurfaceFor(context),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: DigitalRecordColors.borderFor(context)),
              ),
              child: Row(
                children: [
                  _isPreviewableImage(evidence)
                      ? GestureDetector(
                          onTap: () => _showPreview(evidence),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 88,
                              height: 88,
                              color: DigitalRecordColors.evidenceIconBgFor(
                                  context),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FutureBuilder<String>(
                                    future: _previewSourceFor(evidence),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data!.trim().isNotEmpty) {
                                        return _buildPreviewThumbnail(
                                            snapshot.data!);
                                      }
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        );
                                      }
                                      return const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          color: DigitalRecordColors.accent,
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.65),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Icon(
                                        Icons.visibility_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                DigitalRecordColors.evidenceIconBgFor(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _isLikelyPdfEvidence(evidence)
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                            color: DigitalRecordColors.accent,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          evidence.type.trim().isEmpty
                              ? 'Evidencia'
                              : evidence.type,
                          style: SaoTypography.bodyTextBold,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pie de foto: ${_captionFor(evidence)}',
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.textMutedFor(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          evidence.gcsPath.isEmpty
                              ? 'Sin ruta de almacenamiento'
                              : evidence.gcsPath,
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.textMutedFor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        evidence.uploaderName.isEmpty
                            ? 'Sin usuario'
                            : evidence.uploaderName,
                        style: SaoTypography.caption,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(evidence.uploadedAt),
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.textMutedFor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          if (_isPreviewableImage(evidence))
                            OutlinedButton.icon(
                              onPressed: () => _showPreview(evidence),
                              icon: const Icon(Icons.visibility_rounded,
                                  size: 16),
                              label: const Text('Vista previa'),
                            ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: DigitalRecordColors.accentStrong,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: DigitalRecordColors
                                  .accentStrong
                                  .withValues(alpha: 0.45),
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.82),
                            ),
                            onPressed: _downloadingEvidenceId == null
                                ? () => _downloadAndOpen(evidence)
                                : null,
                            icon: _downloadingEvidenceId == evidence.id
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded,
                                    size: 16, color: Colors.white),
                            label: Text(
                              _downloadingEvidenceId == evidence.id
                                  ? 'Descargando...'
                                  : 'Descargar',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AuditSection extends StatelessWidget {
  const _AuditSection({required this.detail});

  final CompletedActivityDetail detail;

  String _actionLabel(String action) {
    switch (action.trim().toUpperCase()) {
      case 'ACTIVITY_CREATED':
        return 'Actividad registrada';
      case 'ASSIGNMENT_CREATED':
      case 'ASSIGNMENT_ACTIVE':
        return 'Asignación registrada';
      case 'ASSIGNMENT_TRANSFERRED':
        return 'Actividad transferida';
      case 'EVIDENCE_UPLOADED':
      case 'EVIDENCE_PATCHED':
        return 'Evidencia actualizada';
      case 'REVIEW_APPROVED':
      case 'ACTIVITY_REVIEW_APPROVED':
        return 'Revisión aprobada';
      case 'REVIEW_REJECTED':
      case 'ACTIVITY_REVIEW_REJECTED':
        return 'Revisión rechazada';
      case 'REVIEW_UPDATED':
        return 'Revisión registrada';
      case 'REPORT_GENERATE':
        return 'Reporte generado';
      default:
        return action.trim().isEmpty
            ? 'Evento registrado'
            : action.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (detail.auditTrail.isEmpty) {
      return const SaoEmptyState(
        icon: Icons.timeline_outlined,
        message: 'No hay eventos de auditoría',
        subtitle:
            'La actividad aún no expone eventos en el rastro de auditoría.',
      );
    }

    return Column(
      children: detail.auditTrail
          .map(
            (entry) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DigitalRecordColors.mutedSurfaceFor(context),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: DigitalRecordColors.borderFor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(_actionLabel(entry.action),
                              style: SaoTypography.bodyTextBold)),
                      Text(
                        _formatDate(entry.timestamp),
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.textMutedFor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.actorName.isEmpty
                        ? (entry.actorEmail.isEmpty
                            ? 'Sistema'
                            : entry.actorEmail)
                        : entry.actorName,
                    style: SaoTypography.caption,
                  ),
                  if (entry.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(entry.notes, style: SaoTypography.bodyTextSmall),
                  ],
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DigitalRecordColors.panelSurfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DigitalRecordColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SaoTypography.sectionTitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChecklistItemData {
  const _ChecklistItemData({
    required this.label,
    required this.help,
    required this.done,
    this.actionLabel,
    this.onTap,
  });

  final String label;
  final String help;
  final bool done;
  final String? actionLabel;
  final Future<void> Function()? onTap;
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});

  final _ChecklistItemData item;

  @override
  Widget build(BuildContext context) {
    final color = item.done ? SaoColors.success : SaoColors.warning;
    final background = item.done
        ? DigitalRecordColors.checklistDoneBgFor(context)
        : DigitalRecordColors.checklistPendingBgFor(context);

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            item.done
                ? Icons.check_circle_rounded
                : Icons.pending_actions_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: SaoTypography.bodyTextBold),
                const SizedBox(height: 2),
                Text(
                  item.help,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.textMutedFor(context),
                  ),
                ),
              ],
            ),
          ),
          if (item.onTap != null) ...[
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.actionLabel ?? 'Abrir',
                  style: SaoTypography.caption.copyWith(
                    color: DigitalRecordColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: DigitalRecordColors.accent,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (item.onTap == null) return child;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            item.onTap?.call();
          },
          child: child,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DigitalRecordColors.chipSurfaceFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DigitalRecordColors.chipBorderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SaoColors.gray500),
          const SizedBox(width: 6),
          Text(label, style: SaoTypography.caption),
        ],
      ),
    );
  }
}

class _CopyablePkChip extends StatelessWidget {
  const _CopyablePkChip({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Copiar PK',
      child: ActionChip(
        onPressed: onTap,
        avatar: const Icon(
          Icons.content_copy_rounded,
          size: 15,
          color: DigitalRecordColors.accent,
        ),
        side: BorderSide(
            color: DigitalRecordColors.accent.withValues(alpha: 0.35)),
        backgroundColor: DigitalRecordColors.chipSurfaceFor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        label: Text(
          value,
          style: SaoTypography.caption.copyWith(
            color: SaoColors.textFor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DigitalRecordColors.chipSurfaceFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DigitalRecordColors.chipBorderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DigitalRecordColors.accent),
          const SizedBox(width: 6),
          Text(label, style: SaoTypography.caption),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DigitalRecordColors.statusBg(label),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(label),
        style: SaoTypography.caption.copyWith(
          color: DigitalRecordColors.statusColor(label),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: SaoTypography.caption.copyWith(
                color: SaoColors.textMutedFor(context),
              ),
            ),
          ),
          Expanded(child: Text(value, style: SaoTypography.bodyText)),
        ],
      ),
    );
  }
}

List<_ChecklistItemData> _buildChecklist(
  CompletedActivityDetail detail, {
  Future<void> Function()? onOpenDocument,
}) {
  final summary = detail.summary;
  final hasIdentity =
      summary.pk.trim().isNotEmpty || summary.id.trim().isNotEmpty;
  final evidenceCount = _visualEvidenceCountFor(detail);
  final hasEvidence = evidenceCount > 0;
  final hasDocument = summary.hasReport;
  final reviewed = summary.reviewedAt.trim().isNotEmpty ||
      summary.reviewDecision.trim().isNotEmpty;
  final reviewResult = _reviewOutcomeLabel(
    summary.reviewDecision,
    hasReport: summary.hasReport,
  );
  final reviewDate = summary.reviewedAt.trim().isNotEmpty
      ? _formatDate(summary.reviewedAt)
      : '';

  return [
    _ChecklistItemData(
      label: 'Identificación del expediente',
      help: hasIdentity
          ? 'El expediente cuenta con folio o identificador.'
          : 'Falta folio o identificador visible.',
      done: hasIdentity,
    ),
    _ChecklistItemData(
      label: 'Evidencia cargada',
      help: hasEvidence
          ? evidenceCount == 1
              ? 'Hay 1 evidencia disponible en el expediente.'
              : 'Hay $evidenceCount evidencias disponibles en el expediente.'
          : 'No hay evidencias registradas todavía.',
      done: hasEvidence,
    ),
    _ChecklistItemData(
      label: 'Documento generado',
      help: hasDocument
          ? 'Haz clic para abrir el reporte en local o descargarlo con confirmación.'
          : 'Aún no existe un documento oficial generado.',
      done: hasDocument,
      actionLabel: hasDocument ? 'Abrir PDF' : null,
      onTap: hasDocument ? onOpenDocument : null,
    ),
    _ChecklistItemData(
      label: 'Revisión registrada',
      help: reviewed
          ? 'Resultado: $reviewResult${reviewDate.isEmpty ? '' : ' · $reviewDate'}.'
          : 'No hay revisión registrada todavía.',
      done: reviewed,
    ),
  ];
}

String _reviewOutcomeLabel(String raw, {required bool hasReport}) {
  final decision = raw.trim().toUpperCase();
  if (decision == 'APPROVE' ||
      decision == 'APPROVED' ||
      decision == 'APROBADO') {
    return 'Aprobado';
  }
  if (decision == 'REJECT' ||
      decision == 'REJECTED' ||
      decision == 'RECHAZADO') {
    return 'Rechazado';
  }
  if (decision == 'CHANGES_REQUIRED' || decision == 'CAMBIOS_REQUERIDOS') {
    return 'Cambios requeridos';
  }
  if (hasReport) {
    return 'Aprobado';
  }
  return 'Registrada';
}

String _visualStatusFor(CompletedActivity item) {
  final decision = item.reviewDecision.trim().toUpperCase();
  if (decision == 'APPROVE' ||
      decision == 'APPROVED' ||
      decision == 'APROBADO') {
    return 'aprobado';
  }
  if (decision == 'REJECT' ||
      decision == 'REJECTED' ||
      decision == 'RECHAZADO') {
    return 'rechazado';
  }
  if (item.hasReport) {
    return 'aprobado';
  }
  if (item.evidenceCount > 0) {
    return 'en_validacion';
  }
  return 'pendiente';
}

String _statusLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'aprobado':
    case 'approved':
      return 'Aprobado';
    case 'rechazado':
    case 'rejected':
      return 'Rechazado';
    case 'en_validacion':
    case 'validacion':
      return 'En validación';
    case 'pendiente':
    default:
      return 'Pendiente';
  }
}

String _formatDate(String raw) {
  if (raw.trim().isEmpty) return 'Sin fecha';
  try {
    final date = DateTime.parse(raw).toLocal();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    final month = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} $month ${date.year} · $hour:$minute';
  } catch (_) {
    return raw;
  }
}
