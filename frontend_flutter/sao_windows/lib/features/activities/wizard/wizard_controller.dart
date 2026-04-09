// lib/features/activities/wizard/wizard_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../../core/constants.dart';
import '../../../core/catalog/sync/catalog_sync_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/today_activity.dart';
import '../../catalog/catalog_repository.dart';
import '../../evidence/pending_evidence_store.dart';
import '../../sync/models/sync_dto.dart';
import '../../sync/services/sync_service.dart';
import 'wizard_validation.dart';
import 'validation/unplanned_validation.dart' as unplanned_val;
import 'models/evidence_draft.dart';

enum RiskLevel { bajo, medio, alto, prioritario }

enum TipoUbicacion { puntual, tramo, general }

enum WizardLocationSource { assignment, operative, manual }

const _uuid = Uuid();

class ProjectRef {
  final String id;
  final String code;
  final String name;

  const ProjectRef({required this.id, required this.code, required this.name});
}

class FrontRef {
  final String id;
  final String name;

  const FrontRef({required this.id, required this.name});
}

class WizardController extends ChangeNotifier {
  final TodayActivity activity;
  final String projectCode;
  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;
  final AppDb database;
  final String currentUserId; // Usuario que está creando la actividad
  final bool isUnplanned; // true → modo actividad no planeada

  late final ActivityDao _dao;

  WizardController({
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
    required this.database,
    required this.currentUserId,
    this.isUnplanned = false,
  }) {
    _dao = ActivityDao(database);
  }

  bool _loading = true;
  bool _draftHydrationReady = false;
  bool get loading => _loading;

  /// Verdadero cuando el usuario pasó el paso 1 en esta sesión del wizard.
  bool _hasPassedStep1 = false;

  static bool _hasMeaningfulPk(int? value) => value != null && value > 0;

  // =========================
  // Estado (form)
  // =========================

  // Paso 1: Contexto
  TimeOfDay? horaInicio;
  TimeOfDay? horaFin;
  String? estadoId;
  String? municipioId;
  String colonia = '';
  double? geoLat;
  double? geoLon;
  double? geoAccuracy;
  double? assignmentGeoLat;
  double? assignmentGeoLon;
  double? operativeGeoLat;
  double? operativeGeoLon;
  WizardLocationSource locationSource = WizardLocationSource.manual;

  String? selectedProjectId;
  String selectedProjectCode = '';
  String selectedProjectName = '';

  String? selectedFrontId;
  String selectedFrontName = '';

  List<ProjectRef> _availableProjects = const [];
  List<FrontRef> _availableFronts = const [];
  List<String> _availableStates = const [];
  List<String> _availableMunicipios = const [];

  // PK editable
  TipoUbicacion tipoUbicacion = TipoUbicacion.puntual;
  int? pkInicio; // Guardado como entero (ej: 142050 para 142+050)
  int? pkFin; // Solo para tramos

  RiskLevel? risk;

  // Paso 2: Clasificación
  CatItem? _selectedActivity;
  CatItem? _selectedSubcategory;
  CatItem? _selectedPurpose;

  String otherSubcategoryText = '';
  final Set<String> selectedTopicIds = {};
  String otherTopicText = '';
  final Set<String> selectedAttendeeIds = {};
  final Map<String, String> attendeeRepresentatives = {};

  CatItem? selectedResult;

  // Paso 2: Minuta / Reporte
  String reportNotes = '';
  final List<String> reportAgreements = [];

  // Actividad no planeada (solo cuando isUnplanned == true)
  String? unplannedReason;
  String unplannedReasonOtherText = '';
  String unplannedReference = ''; // referencia / folio (opcional)

  // Paso 3: Evidencias (con descripción obligatoria)
  final List<EvidenceDraft> evidencias = [];
  bool get hasEvidence => evidencias.isNotEmpty;

  // =========================
  // Init
  // =========================
  Future<void> init() async {
    _draftHydrationReady = false;
    final initialProjectCode = await _resolveInitialProjectCode();

    await _refreshCatalogIfOnline(initialProjectCode);
    _loading = true;
    notifyListeners();

    // Always initialize against the current project code.
    // The shared singleton can already be ready for a different project.
    await catalogRepo.init(projectId: initialProjectCode, forceReload: true);
    appLogger.i(
      'Wizard catalog init project=$initialProjectCode '
      'activities=${catalogRepo.activities.length} '
      'topics=${catalogRepo.temas.length} '
      'results=${catalogRepo.resultados.length} '
      'version=${catalogRepo.currentVersionId ?? 'n/a'}',
    );

    _postInitPreselect(initialProjectCode);
    await _loadContextOptions();
    await _prefillContextFromAssignment();
    await _rehydrateContextFields();
    await _rehydrateReportFields();
    await _recoverWizardStateFromServerIfNeeded(initialProjectCode);
    await _ensureDraftActivity();

    // Auto-fill horaInicio with current time if not already set from startedAt or draft
    if (horaInicio == null) {
      final initNow = DateTime.now();
      horaInicio = TimeOfDay(hour: initNow.hour, minute: initNow.minute);
    }

    _draftHydrationReady = true;
    _loading = false;
    notifyListeners();
  }

  Future<String> _resolveInitialProjectCode() async {
    final normalized = projectCode.trim().toUpperCase();
    if (normalized.isNotEmpty && normalized != kAllProjects) {
      try {
        final projects = await _dao.listActiveProjects();
        final byCode = projects.cast<Project?>().firstWhere(
          (p) => p?.code.trim().toUpperCase() == normalized,
          orElse: () => null,
        );
        if (byCode != null) {
          return byCode.code.trim().toUpperCase();
        }

        final byId = projects.cast<Project?>().firstWhere(
          (p) => p?.id == projectCode.trim(),
          orElse: () => null,
        );
        if (byId != null) {
          return byId.code.trim().toUpperCase();
        }
      } catch (_) {
        // Continue with normalized fallback.
      }
      return normalized;
    }

    try {
      final activityRow = await _dao.getActivityById(activity.id);
      final activityProjectId = activityRow?.projectId.trim() ?? '';
      if (activityProjectId.isNotEmpty) {
        final projects = await _dao.listActiveProjects();
        final match = projects.cast<Project?>().firstWhere(
          (p) => p?.id == activityProjectId,
          orElse: () => null,
        );
        final resolved = (match?.code ?? activityProjectId)
            .trim()
            .toUpperCase();
        if (resolved.isNotEmpty && resolved != kAllProjects) {
          return resolved;
        }
      }
    } catch (e, st) {
      appLogger.w(
        'resolveInitialProjectCode: fallback to TMQ — $e',
        stackTrace: st,
      );
    }

    // Fallback seguro para no inicializar catálogo con el centinela TODOS.
    try {
      final projects = await _dao.listActiveProjects();
      if (projects.isNotEmpty) {
        return projects.first.code.trim().toUpperCase();
      }
    } catch (_) {}
    return 'TMQ';
  }

  Future<void> _refreshCatalogIfOnline(String projectId) async {
    try {
      final connectivity = GetIt.I<ConnectivityService>();
      final online = await connectivity.hasConnection();
      if (!online) return;

      final syncService = GetIt.I<CatalogSyncService>();
      await syncService.ensureCatalogUpToDate(projectId);
    } catch (e, st) {
      appLogger.w('Catalog refresh skipped: $e', error: e, stackTrace: st);
    }
  }

  Future<void> _recoverWizardStateFromServerIfNeeded(
    String initialProjectCode,
  ) async {
    if (_hasMeaningfulWizardState()) {
      return;
    }

    try {
      final existing = await _dao.getActivityById(activity.id);
      if (existing == null) {
        return;
      }

      final hasServerBackedState =
          (existing.serverRevision ?? 0) > 0 ||
          {
            'SYNCED',
            'RECHAZADA',
            'READY_TO_SYNC',
          }.contains((existing.status).trim().toUpperCase()) ||
          activity.isRejected ||
          activity.reviewState.trim().toUpperCase() == 'CHANGES_REQUIRED' ||
          activity.nextAction.trim().toUpperCase() == 'CORREGIR_Y_REENVIAR';
      if (!hasServerBackedState) {
        return;
      }

      if (!GetIt.I.isRegistered<SyncService>()) {
        return;
      }

      var projectId = existing.projectId.trim();
      if (projectId.isEmpty) {
        projectId = (selectedProjectId?.trim().isNotEmpty ?? false)
            ? selectedProjectId!.trim()
            : initialProjectCode;
      }
      if (projectId.isEmpty) {
        return;
      }

      appLogger.i(
        'Attempting wizard backfill from server for sparse activity ${activity.id} (project=$projectId)',
      );
      await GetIt.I<SyncService>().pullChanges(
        projectId: projectId,
        resetActivityCursor: true,
      );
      await _rehydrateContextFields();
      await _rehydrateReportFields();
    } catch (e, st) {
      appLogger.w(
        'Wizard backfill from server skipped: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _postInitPreselect(String initialProjectCode) {
    // Preselección Activity por título (si hay catálogo)
    _selectedActivity = _inferActivityFromTitle(activity.title);
    _selectedSubcategory = null;
    _selectedPurpose = null;

    // Pre-cargar horas de inicio/fin desde la actividad (si ya se iniciaron)
    if (activity.horaInicio != null) {
      horaInicio = TimeOfDay(
        hour: activity.horaInicio!.hour,
        minute: activity.horaInicio!.minute,
      );
    }
    if (activity.horaFin != null) {
      horaFin = TimeOfDay(
        hour: activity.horaFin!.hour,
        minute: activity.horaFin!.minute,
      );
    }

    if (activity.estado.trim().isNotEmpty) {
      estadoId = activity.estado.trim();
    }

    if (activity.municipio.trim().isNotEmpty) {
      municipioId = activity.municipio.trim();
    }

    // Pre-cargar PK desde la actividad
    if (_hasMeaningfulPk(activity.pk)) {
      pkInicio = activity.pk;
      tipoUbicacion = TipoUbicacion.puntual;
    }

    final initialGps = _tryParseGpsLocation(activity.gpsLocation);
    if (initialGps != null) {
      geoLat = initialGps.$1;
      geoLon = initialGps.$2;
      operativeGeoLat = initialGps.$1;
      operativeGeoLon = initialGps.$2;
      locationSource = WizardLocationSource.operative;
    }

    selectedProjectId = initialProjectCode;
    selectedProjectCode = initialProjectCode;
    selectedProjectName = initialProjectCode;
    selectedFrontName = activity.frente;
  }

  static const List<ProjectRef> _fallbackProjects = [
    ProjectRef(id: 'TMQ', code: 'TMQ', name: 'Tren México–Querétaro'),
    ProjectRef(id: 'TAP', code: 'TAP', name: 'Tren AIFA–Pachuca'),
    ProjectRef(id: 'TQI', code: 'TQI', name: 'Tren Querétaro–Irapuato'),
    ProjectRef(id: 'TSNL', code: 'TSNL', name: 'Tren Saltillo–Nuevo Laredo'),
  ];

  List<ProjectRef> get availableProjects =>
      List.unmodifiable(_availableProjects);
  List<FrontRef> get availableFronts => List.unmodifiable(_availableFronts);
  List<String> get availableStates => List.unmodifiable(_availableStates);
  List<String> get availableMunicipios =>
      List.unmodifiable(_availableMunicipios);

  String get contextProjectLabel {
    if (selectedProjectName.trim().isNotEmpty)
      return selectedProjectName.trim();
    if (selectedProjectCode.trim().isNotEmpty)
      return selectedProjectCode.trim();
    return projectCode;
  }

  String get contextFrontLabel {
    if (selectedFrontName.trim().isNotEmpty) return selectedFrontName.trim();
    return activity.frente;
  }

  String get estadoLabel {
    final value = estadoId?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return activity.estado.trim();
  }

  String get municipioLabel {
    final value = municipioId?.trim() ?? '';
    if (value.isNotEmpty) return value;
    return activity.municipio.trim();
  }

  String get contextLocationLabel {
    final municipio = municipioLabel;
    final estado = estadoLabel;
    if (municipio.isNotEmpty && estado.isNotEmpty) return '$municipio, $estado';
    if (municipio.isNotEmpty) return municipio;
    if (estado.isNotEmpty) return estado;
    return 'Sin ubicación';
  }

  Future<void> _loadContextOptions() async {
    final dao = _dao;

    try {
      final projects = await dao.listActiveProjects();
      _availableProjects = projects.isNotEmpty
          ? projects
                .map((p) => ProjectRef(id: p.id, code: p.code, name: p.name))
                .toList()
          : _fallbackProjects;
    } catch (e) {
      appLogger.w('loadProjectOptions: falling back to local projects — $e');
      _availableProjects = _fallbackProjects;
    }

    final selected = _availableProjects.cast<ProjectRef?>().firstWhere(
      (p) => p!.id == selectedProjectId || p.code == projectCode,
      orElse: () => null,
    );

    if (selected != null) {
      selectedProjectId = selected.id;
      selectedProjectCode = selected.code;
      selectedProjectName = selected.name;
    }

    await loadFrontOptionsForProject(selectedProjectCode, notify: false);
    await loadLocationOptionsForProject(selectedProjectCode, notify: false);
  }

  bool _isEmptyOrUnknown(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'sin frente' ||
        normalized == 'sin ubicación' ||
        normalized == 'sin ubicacion';
  }

  String _parseTitlePart(
    String title,
    String marker,
    List<String> stopMarkers,
  ) {
    final source = title.trim();
    final markerIndex = source.toLowerCase().indexOf(marker.toLowerCase());
    if (markerIndex == -1) return '';

    final start = markerIndex + marker.length;
    var end = source.length;
    final tail = source.substring(start);

    for (final stop in stopMarkers) {
      final relative = tail.toLowerCase().indexOf(stop.toLowerCase());
      if (relative != -1) {
        end = start + relative;
        break;
      }
    }

    return source.substring(start, end).replaceAll('•', '').trim();
  }

  Future<void> _prefillContextFromAssignment() async {
    try {
      final assignment = await _resolveBestAssignmentForWizard();

      if (assignment != null) {
        if (_isEmptyOrUnknown(selectedFrontName) &&
            assignment.frente.trim().isNotEmpty) {
          selectedFrontName = assignment.frente.trim();
          final matchingFront = _availableFronts.cast<FrontRef?>().firstWhere(
            (front) =>
                front?.name.trim().toLowerCase() ==
                selectedFrontName.toLowerCase(),
            orElse: () => null,
          );
          if (matchingFront != null) {
            selectedFrontId = matchingFront.id;
          }
        }

        if ((municipioId ?? '').trim().isEmpty &&
            assignment.municipio.trim().isNotEmpty) {
          municipioId = assignment.municipio.trim();
        }
        if ((estadoId ?? '').trim().isEmpty &&
            assignment.estado.trim().isNotEmpty) {
          estadoId = assignment.estado.trim();
        }
        if (!_hasMeaningfulPk(pkInicio) && _hasMeaningfulPk(assignment.pk)) {
          pkInicio = assignment.pk;
          tipoUbicacion = TipoUbicacion.puntual;
        }

        final assignmentCoords = await _resolveAssignmentCoordinatesForActivity(
          activity.id,
        );
        if (assignmentCoords != null) {
          assignmentGeoLat = assignmentCoords.$1;
          assignmentGeoLon = assignmentCoords.$2;
          if (!hasValidGpsCoordinates) {
            geoLat = assignmentCoords.$1;
            geoLon = assignmentCoords.$2;
            locationSource = WizardLocationSource.assignment;
          }
        }

        final resolvedProject = selectedProjectCode.trim().isNotEmpty
            ? selectedProjectCode
            : projectCode;
        final currentEstado = (estadoId ?? '').trim();
        if (currentEstado.isNotEmpty) {
          await loadMunicipiosForCurrentState(
            resolvedProject,
            currentEstado,
            notify: false,
          );
        }
      }

      if (_isEmptyOrUnknown(selectedFrontName)) {
        final parsedFront = _parseTitlePart(activity.title, 'Frente:', const [
          'Estado:',
          'Municipio:',
        ]);
        if (parsedFront.isNotEmpty) {
          selectedFrontName = parsedFront;
        }
      }

      if ((estadoId ?? '').trim().isEmpty) {
        final parsedEstado = _parseTitlePart(activity.title, 'Estado:', const [
          'Municipio:',
        ]);
        if (parsedEstado.isNotEmpty) {
          estadoId = parsedEstado;
        }
      }

      if ((municipioId ?? '').trim().isEmpty) {
        final parsedMunicipio = _parseTitlePart(
          activity.title,
          'Municipio:',
          const [],
        );
        if (parsedMunicipio.isNotEmpty) {
          municipioId = parsedMunicipio;
        }
      }
    } catch (e, st) {
      appLogger.w('prefillContextFromAssignment skipped: $e', stackTrace: st);
    }
  }

  Future<(double, double)?> _resolveAssignmentCoordinatesForActivity(
    String activityId,
  ) async {
    final fields = await _dao.getFieldsByKey(activityId);

    final fromNumbers = (
      fields['assignment_latitude']?.valueNumber,
      fields['assignment_longitude']?.valueNumber,
    );
    if (fromNumbers.$1 != null && fromNumbers.$2 != null) {
      return (fromNumbers.$1!, fromNumbers.$2!);
    }

    final fromText = (
      double.tryParse((fields['assignment_latitude']?.valueText ?? '').trim()),
      double.tryParse((fields['assignment_longitude']?.valueText ?? '').trim()),
    );
    if (fromText.$1 != null && fromText.$2 != null) {
      return (fromText.$1!, fromText.$2!);
    }

    return null;
  }

  Future<AgendaAssignment?> _resolveBestAssignmentForWizard() async {
    // 1) Match directo por id (algunas rutas usan el id de asignación como id de actividad local)
    final direct =
        await ((database.select(database.agendaAssignments)
              ..where(
                (t) =>
                    t.id.equals(activity.id) | t.activityId.equals(activity.id),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull());
    if (direct != null) return direct;

    final projectCandidates = <String>{
      projectCode.trim(),
      selectedProjectId?.trim() ?? '',
      selectedProjectCode.trim(),
    }..removeWhere((value) => value.isEmpty);

    final resolvedProjectId = await _dao.resolveProjectId(
      selectedProjectId ?? selectedProjectCode,
    );
    if (resolvedProjectId.trim().isNotEmpty) {
      projectCandidates.add(resolvedProjectId.trim());
    }

    if (projectCandidates.isEmpty) return null;

    final candidates =
        await ((database.select(database.agendaAssignments)
              ..where((t) => t.projectId.isIn(projectCandidates.toList()))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(200))
            .get());
    if (candidates.isEmpty) return null;

    final activityPk = _hasMeaningfulPk(activity.pk)
        ? activity.pk
        : (_hasMeaningfulPk(pkInicio) ? pkInicio : null);
    final expectedName = _normalizeActivityNameForMatch(activity.title);

    AgendaAssignment? best;
    var bestScore = -1;

    for (final item in candidates) {
      var score = 0;

      if (_hasMeaningfulPk(activityPk) && item.pk == activityPk) {
        score += 5;
      }

      final itemName = _normalizeActivityNameForMatch(item.title);
      if (itemName == expectedName && expectedName.isNotEmpty) {
        score += 3;
      }

      if (!_isEmptyOrUnknown(item.frente)) {
        score += 1;
      }
      if ((item.municipio).trim().isNotEmpty ||
          (item.estado).trim().isNotEmpty) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    // Evita falsos positivos: exigir al menos una coincidencia fuerte
    if (bestScore < 3) return null;
    return best;
  }

  String _normalizeActivityNameForMatch(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final upper = trimmed.toUpperCase();
    const codes = <String, String>{
      'CAM': 'CAMINAMIENTO',
      'REU': 'REUNION',
      'INS': 'INSPECCION',
      'SUP': 'SUPERVISION',
    };

    final expanded = codes[upper] ?? upper;
    return expanded
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> loadFrontOptionsForProject(
    String projectCodeOrId, {
    bool notify = true,
  }) async {
    final dao = _dao;
    try {
      final remoteFronts = await catalogRepo.fetchFrontsForProject(
        projectCodeOrId,
      );
      if (remoteFronts.isNotEmpty) {
        _availableFronts = remoteFronts
            .map((s) => FrontRef(id: s.id, name: s.name))
            .toList();
      } else {
        final segments = await dao.listActiveSegmentsByProject(projectCodeOrId);
        _availableFronts = segments
            .map((s) => FrontRef(id: s.id, name: s.segmentName))
            .toList();
      }
    } catch (e) {
      appLogger.w('loadFrontOptionsForProject: falling back to empty — $e');
      _availableFronts = const [];
    }

    final currentFrontExists =
        selectedFrontId != null &&
        _availableFronts.any((front) => front.id == selectedFrontId);
    if (!currentFrontExists) {
      selectedFrontId = null;
      if (selectedFrontName.trim().isEmpty) {
        selectedFrontName = activity.frente;
      }
    }

    if (notify) notifyListeners();
  }

  Future<void> loadLocationOptionsForProject(
    String projectCodeOrId, {
    bool notify = true,
  }) async {
    try {
      _availableStates = await catalogRepo.fetchStatesForProject(
        projectCodeOrId,
      );
    } catch (e) {
      appLogger.w('loadLocationOptionsForProject: no states loaded — $e');
      _availableStates = const [];
    }

    final currentEstado = (estadoId ?? '').trim();
    if (currentEstado.isNotEmpty && _availableStates.contains(currentEstado)) {
      await loadMunicipiosForCurrentState(
        projectCodeOrId,
        currentEstado,
        notify: false,
      );
    } else {
      _availableMunicipios = const [];
      if (currentEstado.isNotEmpty) {
        estadoId = null;
        municipioId = null;
      }
    }

    if (notify) notifyListeners();
  }

  Future<void> loadMunicipiosForCurrentState(
    String projectCodeOrId,
    String estado, {
    bool notify = true,
  }) async {
    try {
      _availableMunicipios = await catalogRepo.fetchMunicipiosForProject(
        projectCodeOrId,
        estado,
      );
    } catch (e) {
      appLogger.w('loadMunicipiosForCurrentState: no municipios loaded — $e');
      _availableMunicipios = const [];
    }

    final currentMunicipio = (municipioId ?? '').trim();
    if (currentMunicipio.isNotEmpty &&
        !_availableMunicipios.contains(currentMunicipio)) {
      municipioId = null;
    }

    if (notify) notifyListeners();
  }

  // =========================
  // Catálogos (desde CatalogRepository)
  // =========================
  List<CatItem> get activities => catalogRepo.activities;

  List<CatItem> get availableSubcategories {
    final a = _selectedActivity?.id;
    if (a == null) return const [];
    return catalogRepo.subcatsFor(a);
  }

  List<CatItem> get availablePurposes {
    final a = _selectedActivity?.id;
    final s = _selectedSubcategory?.id;
    if (a == null) return const [];
    return catalogRepo.purposesForCascade(activityId: a, subcategoryId: s);
  }

  List<CatItem> get topics {
    final a = _selectedActivity?.id;
    if (a == null) return catalogRepo.temas;
    return catalogRepo.topicsForActivity(a);
  }

  List<CatItem> get suggestedTopics {
    final a = _selectedActivity?.id;
    if (a == null) return const [];
    return catalogRepo.temasSugeridosFor(a);
  }

  List<CatItem> get attendeesInstitutional =>
      catalogRepo.asistentesInstitucionales;
  List<CatItem> get attendeesLocal => catalogRepo.asistentesLocales;

  CatItem? attendeeById(String id) {
    for (final attendee in attendeesInstitutional) {
      if (attendee.id == id) return attendee;
    }
    for (final attendee in attendeesLocal) {
      if (attendee.id == id) return attendee;
    }
    return null;
  }

  List<CatItem> get results => catalogRepo.resultados;

  // =========================
  // Getters selección
  // =========================
  CatItem? get selectedActivity => _selectedActivity;
  CatItem? get selectedSubcategory => _selectedSubcategory;
  CatItem? get selectedPurpose => _selectedPurpose;

  bool get isOtherSubcategory => _selectedSubcategory?.id == 'OTRO_SUB';
  bool get isOtherTopicSelected => selectedTopicIds.contains('OTRO_TEMA');

  // =========================
  // Setters
  // =========================
  void setRisk(RiskLevel v) {
    risk = v;
    notifyListeners();
  }

  void setActivity(CatItem a) {
    _selectedActivity = a;
    _selectedSubcategory = null;
    _selectedPurpose = null;
    otherSubcategoryText = '';
    notifyListeners();
  }

  void setSubcategory(CatItem s) {
    _selectedSubcategory = s;
    _selectedPurpose = null;
    if (!isOtherSubcategory) otherSubcategoryText = '';
    notifyListeners();
  }

  void setPurpose(CatItem p) {
    _selectedPurpose = p;
    notifyListeners();
  }

  void toggleTopic(String id) {
    if (selectedTopicIds.contains(id)) {
      selectedTopicIds.remove(id);
    } else {
      selectedTopicIds.add(id);
    }
    if (!isOtherTopicSelected) otherTopicText = '';
    notifyListeners();
  }

  void toggleAttendee(String id) {
    if (selectedAttendeeIds.contains(id)) {
      selectedAttendeeIds.remove(id);
      attendeeRepresentatives.remove(id);
    } else {
      selectedAttendeeIds.add(id);
    }
    notifyListeners();
  }

  void selectAttendee(String id) {
    if (selectedAttendeeIds.add(id)) {
      notifyListeners();
    }
  }

  void deselectAttendee(String id) {
    final removedAttendee = selectedAttendeeIds.remove(id);
    final removedRepresentative = attendeeRepresentatives.remove(id);
    if (removedAttendee || removedRepresentative != null) {
      notifyListeners();
    }
  }

  void setAttendeeRepresentative(String attendeeId, String representativeName) {
    final normalizedId = attendeeId.trim();
    final normalizedName = representativeName.trim();
    if (normalizedId.isEmpty) return;

    if (normalizedName.isEmpty) {
      attendeeRepresentatives.remove(normalizedId);
    } else {
      attendeeRepresentatives[normalizedId] = normalizedName;
    }
    notifyListeners();
  }

  String? attendeeRepresentative(String attendeeId) {
    final value = attendeeRepresentatives[attendeeId]?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  void setResult(CatItem? r) {
    selectedResult = r;
    notifyListeners();
  }

  void setTipoUbicacion(TipoUbicacion tipo) {
    tipoUbicacion = tipo;
    if (tipo == TipoUbicacion.general) {
      pkInicio = null;
      pkFin = null;
    } else if (tipo == TipoUbicacion.puntual) {
      pkFin = null;
    }
    notifyListeners();
  }

  void setPkInicio(int? pk) {
    pkInicio = pk;
    notifyListeners();
  }

  void setPkFin(int? pk) {
    pkFin = pk;
    notifyListeners();
  }

  void setOtherSubcategoryText(String v) {
    otherSubcategoryText = v;
    notifyListeners();
  }

  void setOtherTopicText(String v) {
    otherTopicText = v;
    notifyListeners();
  }

  void setReportNotes(String value) {
    reportNotes = value;
    notifyListeners();
  }

  void addReportAgreement([String initialValue = '']) {
    reportAgreements.add(initialValue);
    notifyListeners();
  }

  void updateReportAgreement(int index, String value) {
    if (index < 0 || index >= reportAgreements.length) return;
    reportAgreements[index] = value;
    notifyListeners();
  }

  void removeReportAgreementAt(int index) {
    if (index < 0 || index >= reportAgreements.length) return;
    reportAgreements.removeAt(index);
    notifyListeners();
  }

  String getReportNotes() => reportNotes.trim();

  List<String> getReportAgreements() =>
      sanitizeReportAgreements(reportAgreements);

  static List<String> sanitizeReportAgreements(List<String> rawItems) {
    return rawItems
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // Evidencias
  void addPhoto(String path) {
    evidencias.add(EvidenceDraft(localPath: path));
    notifyListeners();
    unawaited(_persistEvidenceDraftsForCurrentActivity());
  }

  void addPhotoWithMetadata(String path, {double? lat, double? lng}) {
    evidencias.add(EvidenceDraft(localPath: path, lat: lat, lng: lng));
    notifyListeners();
    unawaited(_persistEvidenceDraftsForCurrentActivity());
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= evidencias.length) return;
    evidencias.removeAt(index);
    notifyListeners();
    unawaited(
      _persistEvidenceDraftsForCurrentActivity(
        preserveExistingIfCurrentEmpty: false,
      ),
    );
  }

  void updateDescripcion(int index, String descripcion) {
    if (index < 0 || index >= evidencias.length) return;
    evidencias[index].descripcion = descripcion;
    notifyListeners();
  }

  // Tiempo
  void setHoraInicio(TimeOfDay time) {
    horaInicio = time;
    notifyListeners();
  }

  void setHoraFin(TimeOfDay time) {
    horaFin = time;
    notifyListeners();
  }

  // Ubicación
  void setEstado(String? estado) {
    final normalized = estado?.trim() ?? '';
    if ((estadoId ?? '') != normalized) {
      municipioId = null;
      _availableMunicipios = const [];
    }
    estadoId = normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  Future<void> setEstadoAndLoadMunicipios(String? estado) async {
    setEstado(estado);
    final current = estadoId?.trim() ?? '';
    if (current.isEmpty) {
      _availableMunicipios = const [];
      notifyListeners();
      return;
    }
    await loadMunicipiosForCurrentState(
      selectedProjectCode,
      current,
      notify: true,
    );
  }

  void setMunicipio(String? municipio) {
    final normalized = municipio?.trim() ?? '';
    municipioId = normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  void setColonia(String value) {
    colonia = value;
    notifyListeners();
  }

  void setGpsCoordinates({
    required double? latitude,
    required double? longitude,
    double? accuracy,
  }) {
    geoLat = latitude;
    geoLon = longitude;
    geoAccuracy = accuracy;
    notifyListeners();
  }

  bool get hasAssignmentCoordinates =>
      assignmentGeoLat != null && assignmentGeoLon != null;
  bool get hasOperativeCoordinates =>
      operativeGeoLat != null && operativeGeoLon != null;

  void setOperativeCoordinates({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    operativeGeoLat = latitude;
    operativeGeoLon = longitude;
    geoAccuracy = accuracy ?? geoAccuracy;
    notifyListeners();
  }

  void useAssignmentCoordinates() {
    if (!hasAssignmentCoordinates) return;
    geoLat = assignmentGeoLat;
    geoLon = assignmentGeoLon;
    locationSource = WizardLocationSource.assignment;
    notifyListeners();
  }

  void useOperativeCoordinates() {
    if (!hasOperativeCoordinates) return;
    geoLat = operativeGeoLat;
    geoLon = operativeGeoLon;
    locationSource = WizardLocationSource.operative;
    notifyListeners();
  }

  void setManualMapPoint({
    required double latitude,
    required double longitude,
  }) {
    geoLat = latitude;
    geoLon = longitude;
    locationSource = WizardLocationSource.manual;
    notifyListeners();
  }

  void setProject(ProjectRef project) {
    selectedProjectId = project.id;
    selectedProjectCode = project.code;
    selectedProjectName = project.name;
    selectedFrontId = null;
    selectedFrontName = '';
    estadoId = null;
    municipioId = null;
    _availableStates = const [];
    _availableMunicipios = const [];
    unawaited(_refreshCatalogIfOnline(project.code));
    unawaited(
      catalogRepo.loadProjectBundle(project.code).then((_) {
        notifyListeners();
      }),
    );
    notifyListeners();
  }

  void setFront(FrontRef front) {
    selectedFrontId = front.id;
    selectedFrontName = front.name;
    notifyListeners();
  }

  void setFrontName(String value) {
    selectedFrontId = null;
    selectedFrontName = value;
    notifyListeners();
  }

  void setAdminLocation(String? state, String? municipio, String coloniaValue) {
    estadoId = state;
    municipioId = municipio;
    colonia = coloniaValue;
    notifyListeners();
  }

  void setUnplannedReason(String? v) {
    final normalized = v?.trim();
    unplannedReason = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    unplannedReasonOtherText = '';
    notifyListeners();
  }

  void setUnplannedReasonOtherText(String v) {
    unplannedReasonOtherText = v;
    notifyListeners();
  }

  void setUnplannedReference(String v) {
    unplannedReference = v;
    notifyListeners();
  }

  /// Etiqueta legible para el motivo no planeado (usada en la pantalla de confirmación)
  String get unplannedReasonLabel => unplanned_val.labelForUnplannedReason(
    unplannedReason: unplannedReason,
    unplannedReasonOtherText: unplannedReasonOtherText,
  );

  // =========================
  // Validación
  // =========================
  bool get canContinueFromContext => true;

  bool get canContinueFromFields {
    if (risk == null) return false;
    if (_selectedActivity == null) return false;
    if (_selectedSubcategory == null) return false;
    if (isOtherSubcategory && otherSubcategoryText.trim().isEmpty) return false;

    final purposes = availablePurposes;
    if (purposes.isNotEmpty && _selectedPurpose == null) return false;

    if (selectedResult == null) return false;

    if (isOtherTopicSelected && otherTopicText.trim().isEmpty) return false;

    if (reportAgreements.any((item) => item.trim().isEmpty)) return false;

    return true;
  }

  bool get canSave => canContinueFromFields;
  bool get selectedActivityRequiresGeo =>
      _selectedActivity?.requiresGeo ?? false;
  bool get hasValidGpsCoordinates => geoLat != null && geoLon != null;
  int get minimumEvidencePhotosRequired {
    final configured = _selectedActivity?.minimumEvidencePhotos ?? 0;
    if (configured <= 0) return 1;
    return configured;
  }

  // =========================
  // Validación Reactiva ("Encuéntralo por mí")
  // =========================

  /// Valida los campos exclusivos de actividad no planeada.
  /// Retorna valid() si isUnplanned == false.
  /// Delega a la función pura [unplanned_val.validateUnplannedFields] para
  /// permitir testeo sin instanciar el controller completo.
  ValidationResult validateUnplanned() => unplanned_val.validateUnplannedFields(
    isUnplanned: isUnplanned,
    unplannedReason: unplannedReason,
    unplannedReasonOtherText: unplannedReasonOtherText,
  );

  /// Valida el paso de contexto y retorna errores específicos
  ValidationResult validateContextStep() {
    final errors = <ValidationError>[];

    if (isUnplanned &&
        (selectedProjectId == null || selectedProjectId!.trim().isEmpty)) {
      errors.add(
        ValidationError(
          fieldKey: 'project',
          message: 'Selecciona el proyecto para la actividad no planeada',
          step: 'context',
        ),
      );
    }

    if (risk == null) {
      errors.add(
        ValidationError(
          fieldKey: 'risk',
          message: 'Selecciona el nivel de riesgo',
          step: 'context',
        ),
      );
    }

    if (selectedActivityRequiresGeo && !hasValidGpsCoordinates) {
      errors.add(
        ValidationError(
          fieldKey: 'gps_required',
          message:
              'No se pudo obtener ubicación GPS. Activa el GPS y vuelve a intentar.',
          step: 'context',
        ),
      );
    }

    // Incluir validación de campos no planeados
    final unplannedResult = validateUnplanned();
    if (!unplannedResult.isValid) {
      errors.addAll(unplannedResult.errors);
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Valida el paso de clasificación y retorna errores específicos
  ValidationResult validateFieldsStep() {
    final errors = <ValidationError>[];

    // Riesgo (también se valida aquí por si vienen desde paso 1 sin seleccionar)
    if (risk == null) {
      errors.add(
        ValidationError(
          fieldKey: 'risk',
          message: 'Selecciona el nivel de riesgo',
          step: 'fields',
        ),
      );
    }

    // Actividad
    if (_selectedActivity == null) {
      errors.add(
        ValidationError(
          fieldKey: 'activity',
          message: 'Selecciona una actividad principal',
          step: 'fields',
        ),
      );
    }

    // Subcategoría
    if (_selectedSubcategory == null) {
      errors.add(
        ValidationError(
          fieldKey: 'subcategory',
          message: 'Selecciona una subcategoría',
          step: 'fields',
        ),
      );
    } else if (isOtherSubcategory && otherSubcategoryText.trim().isEmpty) {
      errors.add(
        ValidationError(
          fieldKey: 'subcategory_other',
          message: 'Escribe el nombre de la nueva subcategoría',
          step: 'fields',
        ),
      );
    }

    // Propósito (solo si hay propósitos disponibles)
    final purposes = availablePurposes;
    if (purposes.isNotEmpty && _selectedPurpose == null) {
      errors.add(
        ValidationError(
          fieldKey: 'purpose',
          message: 'Selecciona un propósito',
          step: 'fields',
        ),
      );
    }

    // Temas (validar si se seleccionó "Otro tema" pero no escribió)
    if (isOtherTopicSelected && otherTopicText.trim().isEmpty) {
      errors.add(
        ValidationError(
          fieldKey: 'topic_other',
          message: 'Escribe el nombre del tema personalizado',
          step: 'fields',
        ),
      );
    }

    // Resultado
    if (selectedResult == null) {
      errors.add(
        ValidationError(
          fieldKey: 'result',
          message: 'Selecciona un resultado',
          step: 'fields',
        ),
      );
    }

    if (reportAgreements.any((item) => item.trim().isEmpty)) {
      errors.add(
        ValidationError(
          fieldKey: 'report_agreements',
          message: 'Completa o elimina acuerdos vacíos',
          step: 'fields',
        ),
      );
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  /// Valida que haya evidencia cargada
  ValidationResult validateEvidenceStep() {
    final errors = <ValidationError>[];

    if (evidencias.length < minimumEvidencePhotosRequired) {
      errors.add(
        ValidationError(
          fieldKey: 'evidence',
          message:
              'Agrega al menos $minimumEvidencePhotosRequired evidencia(s).',
          step: 'evidence',
        ),
      );
    }

    return errors.isEmpty
        ? ValidationResult.valid()
        : ValidationResult.invalid(errors);
  }

  // =========================
  // GATEKEEPER - Validación Final Estricta
  // =========================

  /// Validación completa antes de guardar (Gatekeeper)
  /// Prioriza evidencia, luego resto de campos
  /// Retorna el índice de evidencia sin descripción si aplica
  GatekeeperResult validateBeforeSave() {
    if (isUnplanned &&
        (selectedProjectId == null || selectedProjectId!.trim().isEmpty)) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona el proyecto para la actividad no planeada.',
        errorFieldKey: 'project',
        step: 0,
      );
    }

    // PRIORIDAD 1: Evidencia
    if (evidencias.length < minimumEvidencePhotosRequired) {
      return GatekeeperResult(
        isValid: false,
        errorMessage:
            'Debes adjuntar al menos $minimumEvidencePhotosRequired foto(s) de evidencia.',
        errorFieldKey: 'btn_agregar_foto',
        step: 2, // Paso de evidencia (0-indexed)
      );
    }

    // Buscar primera foto sin descripción
    final indexSinDescripcion = evidencias.indexWhere((e) => !e.isValid);
    if (indexSinDescripcion != -1) {
      return GatekeeperResult(
        isValid: false,
        errorMessage:
            'Falta descripción en la foto ${indexSinDescripcion + 1}.',
        errorFieldKey: 'input_descripcion_$indexSinDescripcion',
        step: 2,
        evidenceIndex: indexSinDescripcion,
      );
    }

    // PRIORIDAD 2: Tiempo
    if (horaInicio == null || horaFin == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Define el horario de la actividad (inicio y fin).',
        errorFieldKey: 'horario_section',
        step: 0,
      );
    }

    // Validar que hora fin sea posterior
    final inicioMinutos = horaInicio!.hour * 60 + horaInicio!.minute;
    final finMinutos = horaFin!.hour * 60 + horaFin!.minute;
    if (finMinutos <= inicioMinutos) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'La hora fin debe ser posterior a la hora inicio.',
        errorFieldKey: 'hora_fin',
        step: 0,
      );
    }

    // PRIORIDAD 3: Ubicación
    if (municipioId == null || colonia.trim().isEmpty) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Completa la ubicación geográfica (municipio y colonia).',
        errorFieldKey: 'ubicacion_section',
        step: 0,
      );
    }

    if (selectedActivityRequiresGeo && !hasValidGpsCoordinates) {
      return GatekeeperResult(
        isValid: false,
        errorMessage:
            'No se pudo obtener ubicación GPS. Activa el GPS y vuelve a intentar.',
        errorFieldKey: 'gps_required',
        step: 0,
      );
    }

    // PRIORIDAD 4: Riesgo
    if (risk == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona el nivel de riesgo.',
        errorFieldKey: 'risk',
        step: 0,
      );
    }

    // PRIORIDAD 4.5: No planeada
    if (isUnplanned && unplannedReason == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Describe el motivo de la actividad no planeada.',
        errorFieldKey: 'unplanned_reason',
        step: 0,
      );
    }
    // PRIORIDAD 5: Clasificación
    if (_selectedActivity == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona una actividad principal.',
        errorFieldKey: 'activity',
        step: 1,
      );
    }

    if (_selectedSubcategory == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona una subcategoría.',
        errorFieldKey: 'subcategory',
        step: 1,
      );
    }

    if (reportAgreements.any((item) => item.trim().isEmpty)) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Completa o elimina acuerdos vacíos en Minuta / Reporte.',
        errorFieldKey: 'report_agreements',
        step: 1,
      );
    }

    // PRIORIDAD 6: Temas
    if (selectedTopicIds.isEmpty) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona al menos un tema tratado.',
        errorFieldKey: 'temas_section',
        step: 1,
      );
    }

    // PRIORIDAD 7: Asistentes
    if (selectedAttendeeIds.isEmpty) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Agrega a los asistentes.',
        errorFieldKey: 'asistentes_section',
        step: 1,
      );
    }

    // PRIORIDAD 8: Resultado
    if (selectedResult == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona el resultado final.',
        errorFieldKey: 'resultado',
        step: 3,
      );
    }

    return GatekeeperResult(isValid: true);
  }

  // =========================
  // Inferencia local
  // =========================
  CatItem? _inferActivityFromTitle(String title) {
    final list = activities;
    if (list.isEmpty) return null;

    final t = title.toLowerCase();

    CatItem? find(String id) {
      for (final x in list) {
        if (x.id == id) return x;
      }
      return null;
    }

    if (t.contains('asamblea')) return find('ASA') ?? list.first;
    if (t.contains('reunión') || t.contains('reunion'))
      return find('REU') ?? list.first;
    if (t.contains('camin')) return find('CAM') ?? list.first;

    return find('CAM') ?? list.first;
  }

  // =========================
  // Guardado en Drift
  // =========================

  /// Guarda la actividad completa en la base de datos local
  Future<String> saveToDatabase({
    String? projectId,
    String? activityTypeId,
    String? segmentId,
    int? pk,
    String? pkRefType,
    bool allowPendingWithoutEvidence = false,
  }) async {
    try {
      final dao = _dao;
      await _ensureDraftActivity();
      final hasExistingActivity = await dao.activityExists(activity.id);
      final existingActivity = hasExistingActivity
          ? await dao.getActivityById(activity.id)
          : null;
      final activityId = hasExistingActivity ? activity.id : _uuid.v4();
      final now = DateTime.now();
      // Derive start/end timestamps from time pickers for accurate recording
      final DateTime resolvedStartedAt = horaInicio != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              horaInicio!.hour,
              horaInicio!.minute,
            )
          : (activity.horaInicio ?? now);
      final DateTime resolvedFinishedAt = horaFin != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              horaFin!.hour,
              horaFin!.minute,
            )
          : now;
      final cleanedNotes = getReportNotes();
      final cleanedAgreements = getReportAgreements();
      final existingSnapshot = await _loadExistingWizardPayloadSnapshot(
        activity.id,
      );
      final wizardPayloadSnapshot = _buildWizardPayloadForSync(
        existingSnapshot: existingSnapshot,
      );

      final selectedActivityId = _selectedActivity?.id;
      if (selectedActivityId == null || selectedActivityId.trim().isEmpty) {
        throw StateError('No activity selected from effective catalog');
      }

      final selectedActivityName = _selectedActivity?.name.trim();
      final resolvedTitle =
          (selectedActivityName != null && selectedActivityName.isNotEmpty)
          ? selectedActivityName
          : activity.title.trim();

      final requestedProjectId = (projectId?.trim().isNotEmpty ?? false)
          ? projectId!.trim()
          : ((selectedProjectId?.trim().isNotEmpty ?? false)
                ? selectedProjectId!.trim()
                : projectCode);
      final requestedActivityTypeId =
          (activityTypeId?.trim().isNotEmpty ?? false)
          ? activityTypeId!.trim()
          : selectedActivityId.trim();
      final selectedSegmentId = (selectedFrontId?.trim().isNotEmpty ?? false)
          ? selectedFrontId!.trim()
          : null;
      final requestedSegmentId = (segmentId?.trim().isNotEmpty ?? false)
          ? segmentId!.trim()
          : selectedSegmentId;

      var resolvedProjectId = await dao.resolveProjectId(requestedProjectId);
      var resolvedActivityTypeId = await dao.resolveActivityTypeId(
        requestedActivityTypeId,
      );
      final effectivePk = pk ?? pkInicio ?? existingActivity?.pk ?? activity.pk;
      final effectivePkRefType =
          pkRefType ??
          existingActivity?.pkRefType ??
          switch (tipoUbicacion) {
            TipoUbicacion.puntual => 'PK',
            TipoUbicacion.tramo => 'TRAMO',
            TipoUbicacion.general => 'GENERAL',
          };

      if (hasExistingActivity && !isUnplanned) {
        final existing = await dao.getActivityById(activity.id);
        if (existing != null) {
          resolvedProjectId = existing.projectId;
          resolvedActivityTypeId = existing.activityTypeId;
        }
      }

      final saveAsPending =
          !isUnplanned && !hasEvidence && allowPendingWithoutEvidence;
      final activityStatus = isUnplanned
          ? 'REVISION_PENDIENTE'
          : (saveAsPending ? 'DRAFT' : 'READY_TO_SYNC');

      // Preparar datos de la actividad principal
      final activityCompanion = ActivitiesCompanion.insert(
        id: activityId,
        projectId: resolvedProjectId,
        segmentId: drift.Value(requestedSegmentId),
        activityTypeId: resolvedActivityTypeId,
        title: resolvedTitle,
        description: drift.Value(_buildDescription()),
        pk: drift.Value(effectivePk),
        pkRefType: drift.Value(effectivePkRefType),
        createdAt: now,
        createdByUserId: currentUserId,
        status: drift.Value(activityStatus),
        startedAt: drift.Value(resolvedStartedAt),
        finishedAt: (isUnplanned || saveAsPending)
            ? const drift.Value(null)
            : drift.Value(resolvedFinishedAt),
        geoLat: drift.Value(geoLat),
        geoLon: drift.Value(geoLon),
        geoAccuracy: drift.Value(geoAccuracy),
        catalogVersionId: drift.Value(catalogRepo.currentVersionId),
      );

      // Preparar fields custom
      final fields = <ActivityFieldsCompanion>[
        // Riesgo
        ActivityFieldsCompanion.insert(
          id: _uuid.v4(),
          activityId: activityId,
          fieldKey: 'risk_level',
          valueText: drift.Value(risk?.name),
        ),

        // Actividad
        if (_selectedActivity != null)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'activity_type',
            valueText: drift.Value(_selectedActivity!.id),
          ),

        // Subcategoría
        if (_selectedSubcategory != null)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'subcategory',
            valueText: drift.Value(_selectedSubcategory!.id),
          ),

        if (selectedFrontId != null && selectedFrontId!.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'front_id',
            valueText: drift.Value(selectedFrontId!.trim()),
          )
        else if (selectedFrontName.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'front_name',
            valueText: drift.Value(selectedFrontName.trim()),
          ),

        if (estadoId?.trim().isNotEmpty ?? false)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'estado',
            valueText: drift.Value(estadoId!.trim()),
          ),

        if (municipioId?.trim().isNotEmpty ?? false)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'municipio',
            valueText: drift.Value(municipioId!.trim()),
          ),

        if (colonia.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'colonia',
            valueText: drift.Value(colonia.trim()),
          ),

        // Subcategoría otro (texto)
        if (isOtherSubcategory && otherSubcategoryText.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'subcategory_other_text',
            valueText: drift.Value(otherSubcategoryText.trim()),
          ),

        // Propósito
        if (_selectedPurpose != null)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'purpose',
            valueText: drift.Value(_selectedPurpose!.id),
          ),

        // Temas (JSON array de IDs)
        if (selectedTopicIds.isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'topics',
            valueJson: drift.Value(jsonEncode(selectedTopicIds.toList())),
          ),

        // Tema otro (texto)
        if (isOtherTopicSelected && otherTopicText.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'topic_other_text',
            valueText: drift.Value(otherTopicText.trim()),
          ),

        // Asistentes (JSON array de IDs)
        if (selectedAttendeeIds.isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'attendees',
            valueJson: drift.Value(jsonEncode(selectedAttendeeIds.toList())),
          ),

        if (attendeeRepresentatives.isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'attendee_representatives',
            valueJson: drift.Value(jsonEncode(attendeeRepresentatives)),
          ),

        // Resultado
        if (selectedResult != null)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'result',
            valueText: drift.Value(selectedResult!.id),
          ),

        // Ha evidencia flag
        ActivityFieldsCompanion.insert(
          id: _uuid.v4(),
          activityId: activityId,
          fieldKey: 'has_evidence',
          valueText: drift.Value(hasEvidence ? 'true' : 'false'),
        ),

        if (saveAsPending)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'evidence_pending',
            valueText: const drift.Value('true'),
          ),

        // Notas narrativas para minuta/reporte
        if (cleanedNotes.isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'report_notes',
            valueText: drift.Value(cleanedNotes),
          ),

        // Acuerdos / pendientes
        if (cleanedAgreements.isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'report_agreements',
            valueJson: drift.Value(jsonEncode(cleanedAgreements)),
          ),

        ActivityFieldsCompanion.insert(
          id: '$activityId:wizard_payload_snapshot',
          activityId: activityId,
          fieldKey: 'wizard_payload_snapshot',
          valueJson: drift.Value(jsonEncode(wizardPayloadSnapshot)),
        ),

        // ── Actividad no planeada ──────────────────────────
        if (isUnplanned)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'origin',
            valueText: const drift.Value('unplanned'),
          ),

        if (isUnplanned && unplannedReason != null)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'unplanned_reason',
            valueText: drift.Value(unplannedReason),
          ),

        if (isUnplanned && unplannedReasonOtherText.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'unplanned_reason_other_text',
            valueText: drift.Value(unplannedReasonOtherText.trim()),
          ),

        if (isUnplanned && unplannedReference.trim().isNotEmpty)
          ActivityFieldsCompanion.insert(
            id: _uuid.v4(),
            activityId: activityId,
            fieldKey: 'unplanned_reference',
            valueText: drift.Value(unplannedReference.trim()),
          ),
      ];

      // Guardar en DB usando el DAO
      await dao.upsertDraft(activity: activityCompanion, fields: fields);

      // Guardar evidencias en DB y encolar su subida al backend
      await _saveEvidencesToDb(activityId);
      await _queuePendingEvidenceUploads(activityId);

      // Encolar para sincronización (solo actividades completadas)
      if (activityStatus == 'READY_TO_SYNC') {
        await _enqueueForSync(activityId, activityCompanion);
        _triggerBackgroundPush();
      }

      appLogger.i('Actividad guardada exitosamente: $activityId');
      return activityId;
    } catch (e, stack) {
      appLogger.e('Error guardando actividad', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _rehydrateReportFields() async {
    final dao = _dao;
    final fields = await dao.getFieldsByKey(activity.id);

    final notesField = fields['report_notes'];
    if (notesField?.valueText != null) {
      reportNotes = notesField!.valueText!;
    }

    final agreementsField = fields['report_agreements'];
    if (agreementsField?.valueJson != null &&
        agreementsField!.valueJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(agreementsField.valueJson!);
        if (decoded is List) {
          reportAgreements
            ..clear()
            ..addAll(decoded.map((item) => item.toString()));
        }
      } catch (_) {
        // Ignora JSON inválido y conserva estado por defecto
      }
    }
  }

  Future<void> _rehydrateContextFields() async {
    final dao = _dao;
    final fields = await dao.getFieldsByKey(activity.id);
    final existingActivity = await dao.getActivityById(activity.id);

    if (existingActivity != null && !hasValidGpsCoordinates) {
      geoLat = existingActivity.geoLat;
      geoLon = existingActivity.geoLon;
      geoAccuracy = existingActivity.geoAccuracy;
      if (existingActivity.geoLat != null && existingActivity.geoLon != null) {
        operativeGeoLat = existingActivity.geoLat;
        operativeGeoLon = existingActivity.geoLon;
      }
    }

    final assignmentCoords = await _resolveAssignmentCoordinatesForActivity(
      activity.id,
    );
    if (assignmentCoords != null) {
      assignmentGeoLat = assignmentCoords.$1;
      assignmentGeoLon = assignmentCoords.$2;
      if (!hasValidGpsCoordinates) {
        geoLat = assignmentCoords.$1;
        geoLon = assignmentCoords.$2;
        locationSource = WizardLocationSource.assignment;
      }
    }

    // Frente
    final frontIdField = fields['front_id'];
    if (frontIdField?.valueText != null &&
        frontIdField!.valueText!.trim().isNotEmpty) {
      selectedFrontId = frontIdField.valueText!.trim();
      final match = _availableFronts.cast<FrontRef?>().firstWhere(
        (front) => front!.id == selectedFrontId,
        orElse: () => null,
      );
      if (match != null) {
        selectedFrontName = match.name;
      }
    }

    final frontNameField = fields['front_name'];
    if (frontNameField?.valueText != null &&
        frontNameField!.valueText!.trim().isNotEmpty) {
      selectedFrontName = frontNameField.valueText!.trim();
    }

    final draftProjectIdField = fields['draft_project_id'];
    if (draftProjectIdField?.valueText != null &&
        draftProjectIdField!.valueText!.trim().isNotEmpty) {
      selectedProjectId = draftProjectIdField.valueText!.trim();
    }
    final draftProjectCodeField = fields['draft_project_code'];
    if (draftProjectCodeField?.valueText != null &&
        draftProjectCodeField!.valueText!.trim().isNotEmpty) {
      selectedProjectCode = draftProjectCodeField.valueText!.trim();
    }
    final draftProjectNameField = fields['draft_project_name'];
    if (draftProjectNameField?.valueText != null &&
        draftProjectNameField!.valueText!.trim().isNotEmpty) {
      selectedProjectName = draftProjectNameField.valueText!.trim();
    }

    final draftEstadoField = fields['draft_estado'];
    if (draftEstadoField?.valueText != null &&
        draftEstadoField!.valueText!.trim().isNotEmpty) {
      estadoId = draftEstadoField.valueText!.trim();
    }
    if ((estadoId ?? '').trim().isEmpty) {
      final estadoField = fields['estado'];
      if (estadoField?.valueText != null &&
          estadoField!.valueText!.trim().isNotEmpty) {
        estadoId = estadoField.valueText!.trim();
      }
    }
    final draftMunicipioField = fields['draft_municipio'];
    if (draftMunicipioField?.valueText != null &&
        draftMunicipioField!.valueText!.trim().isNotEmpty) {
      municipioId = draftMunicipioField.valueText!.trim();
    }
    if ((municipioId ?? '').trim().isEmpty) {
      final municipioField = fields['municipio'];
      if (municipioField?.valueText != null &&
          municipioField!.valueText!.trim().isNotEmpty) {
        municipioId = municipioField.valueText!.trim();
      }
    }
    final draftColoniaField = fields['draft_colonia'];
    if (draftColoniaField?.valueText != null &&
        draftColoniaField!.valueText!.trim().isNotEmpty) {
      colonia = draftColoniaField.valueText!.trim();
    }
    if (colonia.trim().isEmpty) {
      final coloniaField = fields['colonia'];
      if (coloniaField?.valueText != null &&
          coloniaField!.valueText!.trim().isNotEmpty) {
        colonia = coloniaField.valueText!.trim();
      }
    }

    final draftTipoUbicacionField = fields['draft_tipo_ubicacion'];
    if (draftTipoUbicacionField?.valueText != null &&
        draftTipoUbicacionField!.valueText!.trim().isNotEmpty) {
      final value = draftTipoUbicacionField.valueText!.trim();
      final match = TipoUbicacion.values.cast<TipoUbicacion?>().firstWhere(
        (item) => item?.name == value,
        orElse: () => null,
      );
      if (match != null) {
        tipoUbicacion = match;
      }
    }

    final draftPkInicioField = fields['draft_pk_inicio'];
    if (draftPkInicioField?.valueText != null &&
        draftPkInicioField!.valueText!.trim().isNotEmpty) {
      pkInicio ??= int.tryParse(draftPkInicioField.valueText!.trim());
    }
    final draftPkFinField = fields['draft_pk_fin'];
    if (draftPkFinField?.valueText != null &&
        draftPkFinField!.valueText!.trim().isNotEmpty) {
      pkFin ??= int.tryParse(draftPkFinField.valueText!.trim());
    }

    // Nivel de riesgo
    final riskField = fields['risk_level'];
    if (riskField?.valueText != null) {
      try {
        risk = RiskLevel.values.firstWhere(
          (r) => r.name == riskField!.valueText,
        );
      } catch (_) {}
    }

    // Tipo de actividad
    final activityTypeField = fields['activity_type'];
    if (activityTypeField?.valueText != null) {
      final found = catalogRepo.activities.cast<CatItem?>().firstWhere(
        (a) => a?.id == activityTypeField!.valueText,
        orElse: () => null,
      );
      if (found != null) _selectedActivity = found;
    }

    // Subcategoría
    if (_selectedActivity != null) {
      final subcatField = fields['subcategory'];
      if (subcatField?.valueText != null) {
        final found = catalogRepo
            .subcatsFor(_selectedActivity!.id)
            .cast<CatItem?>()
            .firstWhere(
              (s) => s?.id == subcatField!.valueText,
              orElse: () => null,
            );
        if (found != null) _selectedSubcategory = found;
      }

      // Propósito
      if (_selectedSubcategory != null) {
        final purposeField = fields['purpose'];
        if (purposeField?.valueText != null) {
          final found = catalogRepo
              .purposesForCascade(
                activityId: _selectedActivity!.id,
                subcategoryId: _selectedSubcategory!.id,
              )
              .cast<CatItem?>()
              .firstWhere(
                (p) => p?.id == purposeField!.valueText,
                orElse: () => null,
              );
          if (found != null) _selectedPurpose = found;
        }
      }
    }

    // Texto de subcategoría "otro"
    final subcatOtherField = fields['subcategory_other_text'];
    if (subcatOtherField?.valueText != null) {
      otherSubcategoryText = subcatOtherField!.valueText!;
    }

    // Temas
    if (selectedTopicIds.isEmpty) {
      final topicsField = fields['topics'];
      if (topicsField?.valueJson != null) {
        try {
          final decoded = jsonDecode(topicsField!.valueJson!);
          if (decoded is List)
            selectedTopicIds.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      }
    }

    final topicOtherField = fields['topic_other_text'];
    if (topicOtherField?.valueText != null) {
      otherTopicText = topicOtherField!.valueText!;
    }

    // Asistentes
    if (selectedAttendeeIds.isEmpty) {
      final attendeesField = fields['attendees'];
      if (attendeesField?.valueJson != null) {
        try {
          final decoded = jsonDecode(attendeesField!.valueJson!);
          if (decoded is List)
            selectedAttendeeIds.addAll(decoded.map((e) => e.toString()));
        } catch (_) {}
      }
    }

    final representativesField = fields['attendee_representatives'];
    if (representativesField?.valueJson != null &&
        representativesField!.valueJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(representativesField.valueJson!);
        if (decoded is Map) {
          attendeeRepresentatives
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) =>
                    MapEntry(key.toString(), value.toString().trim()),
              )..removeWhere((_, value) => value.isEmpty),
            );
        }
      } catch (_) {}
    }

    // Resultado
    if (selectedResult == null) {
      final resultField = fields['result'];
      if (resultField?.valueText != null) {
        final found = catalogRepo.resultados.cast<CatItem?>().firstWhere(
          (r) => r?.id == resultField!.valueText,
          orElse: () => null,
        );
        if (found != null) selectedResult = found;
      }
    }

    // PK desde actividad existente
    if (_hasMeaningfulPk(existingActivity?.pk) && !_hasMeaningfulPk(pkInicio)) {
      pkInicio = existingActivity!.pk;
    }

    // Hora inicio / fin guardadas como draft fields
    final horaInicioField = fields['draft_hora_inicio'];
    if (horaInicioField?.valueText != null && horaInicio == null) {
      final parts = horaInicioField!.valueText!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) horaInicio = TimeOfDay(hour: h, minute: m);
      }
    }

    final horaFinField = fields['draft_hora_fin'];
    if (horaFinField?.valueText != null && horaFin == null) {
      final parts = horaFinField!.valueText!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) horaFin = TimeOfDay(hour: h, minute: m);
      }
    }

    // Motivo actividad no planeada
    if (isUnplanned && unplannedReason == null) {
      final reasonField = fields['unplanned_reason'];
      if (reasonField?.valueText != null)
        unplannedReason = reasonField!.valueText;

      final reasonOtherField = fields['unplanned_reason_other_text'];
      if (reasonOtherField?.valueText != null) {
        unplannedReasonOtherText = reasonOtherField!.valueText!;
      }

      final refField = fields['unplanned_reference'];
      if (refField?.valueText != null)
        unplannedReference = refField!.valueText!;
    }

    // Evidencias guardadas en DB
    await _rehydrateEvidences();
  }

  Future<void> _rehydrateEvidences() async {
    if (evidencias.isNotEmpty) return;
    try {
      final dao = _dao;
      final dbEvidences = await dao.getEvidencesForActivity(activity.id);
      if (dbEvidences.isNotEmpty) {
        for (final ev in dbEvidences) {
          evidencias.add(
            EvidenceDraft(
              localPath: ev.filePathLocal,
              descripcion: ev.caption ?? '',
              createdAt: ev.takenAt ?? DateTime.now(),
              lat: ev.geoLat,
              lng: ev.geoLon,
            ),
          );
        }
        return;
      }

      final recovered = await _loadEvidenceDraftsFromPersistedSources(
        activity.id,
      );
      if (recovered.isEmpty) return;

      evidencias.addAll(recovered);
      await _saveEvidencesToDb(
        activity.id,
        preserveExistingIfCurrentEmpty: false,
      );
      await _queuePendingEvidenceUploads(activity.id);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _loadExistingWizardPayloadSnapshot(
    String activityId,
  ) async {
    final row =
        await ((database.select(database.activityFields)
              ..where(
                (t) =>
                    t.activityId.equals(activityId) &
                    t.fieldKey.equals('wizard_payload_snapshot'),
              )
              ..limit(1))
            .getSingleOrNull());
    final raw = row?.valueJson?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore malformed local snapshot and keep current in-memory state.
    }
    return null;
  }

  Future<List<EvidenceDraft>> _loadEvidenceDraftsFromPersistedSources(
    String activityId,
  ) async {
    Map<String, dynamic>? payload = await _loadExistingWizardPayloadSnapshot(
      activityId,
    );

    if (payload == null || payload.isEmpty) {
      final queueRow =
          await ((database.select(database.syncQueue)
                ..where(
                  (t) =>
                      t.entity.equals('ACTIVITY') &
                      t.entityId.equals(activityId),
                )
                ..orderBy([(t) => drift.OrderingTerm.desc(t.priority)])
                ..limit(1))
              .getSingleOrNull());
      final raw = queueRow?.payloadJson?.trim();
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map && decoded['wizard_payload'] is Map) {
            payload = Map<String, dynamic>.from(
              decoded['wizard_payload'] as Map,
            );
          }
        } catch (_) {
          // Ignore malformed queue payloads.
        }
      }
    }

    final rawItems = payload?['evidences'];
    if (rawItems is! List) {
      return const [];
    }

    final recovered = <EvidenceDraft>[];
    for (final item in rawItems) {
      if (item is! Map) continue;
      try {
        final draft = EvidenceDraft.fromJson(Map<String, dynamic>.from(item));
        if (draft.localPath.trim().isNotEmpty) {
          recovered.add(draft);
        }
      } catch (_) {
        // Skip malformed persisted evidence entries.
      }
    }
    return recovered;
  }

  // =========================
  // Draft persistence helpers
  // =========================

  /// Ensures a DRAFT activity row exists in DB for this wizard session.
  /// Only inserts if the activity doesn't exist yet (for new unplanned activities).
  Future<void> _ensureDraftActivity() async {
    try {
      final dao = _dao;
      if (await dao.activityExists(activity.id)) return;

      final preferredProject = selectedProjectId?.trim().isNotEmpty == true
          ? selectedProjectId!.trim()
          : projectCode.trim();
      var resolvedProjectId = await dao.resolveProjectId(preferredProject);
      if (resolvedProjectId.trim() == preferredProject) {
        final fromAssignment = await _resolveProjectIdFromAssignment(
          activity.id,
        );
        if (fromAssignment != null && fromAssignment.isNotEmpty) {
          resolvedProjectId = fromAssignment;
        }
      }
      final typeId = _selectedActivity?.id ?? activity.title;
      final resolvedTypeId = await dao.resolveActivityTypeId(typeId);
      final resolvedAssignedToUserId = await _resolveAssignedUserIdForSync(
        activity.id,
      );

      await dao.upsertActivityRow(
        ActivitiesCompanion.insert(
          id: activity.id,
          projectId: resolvedProjectId,
          activityTypeId: resolvedTypeId,
          segmentId: drift.Value(
            selectedFrontId?.trim().isNotEmpty == true
                ? selectedFrontId!.trim()
                : null,
          ),
          title: activity.title.isNotEmpty ? activity.title : 'Actividad',
          createdAt: DateTime.now(),
          createdByUserId: currentUserId,
          assignedToUserId: drift.Value(resolvedAssignedToUserId),
          pk: drift.Value(pkInicio ?? activity.pk),
          catalogVersionId: drift.Value(catalogRepo.currentVersionId),
        ),
      );
    } catch (e) {
      appLogger.w('_ensureDraftActivity failed silently: $e');
    }
  }

  /// Saves all current form fields and evidences to DB as a draft.
  /// Safe to call on exit — never throws.
  Future<void> saveDraftSilently() async {
    if (_loading || !_draftHydrationReady) {
      appLogger.d(
        'Skipping draft autosave while wizard is still hydrating: ${activity.id}',
      );
      return;
    }

    try {
      final dao = _dao;
      final activityId = activity.id;
      final existing = await dao.getActivityById(activityId);

      // Usar siempre el projectId de la fila existente para evitar corrupción por FK
      // cuando el usuario tiene "todos los proyectos" seleccionado (__all__).
      final String resolvedProjectId;
      if (selectedProjectId?.trim().isNotEmpty == true) {
        resolvedProjectId = await dao.resolveProjectId(
          selectedProjectId!.trim(),
        );
      } else if (existing != null) {
        resolvedProjectId =
            existing.projectId; // Preservar el proyecto del servidor
      } else {
        final preferredProject = projectCode.trim();
        var candidate = await dao.resolveProjectId(preferredProject);
        if (candidate.trim() == preferredProject) {
          final fromAssignment = await _resolveProjectIdFromAssignment(
            activityId,
          );
          if (fromAssignment != null && fromAssignment.isNotEmpty) {
            candidate = fromAssignment;
          }
        }
        resolvedProjectId = candidate;
      }

      final typeId =
          _selectedActivity?.id ?? existing?.activityTypeId ?? activity.title;
      final resolvedTypeId = await dao.resolveActivityTypeId(typeId);
      final resolvedAssignedToUserId = await _resolveAssignedUserIdForSync(
        activityId,
      );

      final now = DateTime.now();
      final descText = _buildDescription();

      // Si el usuario pasó el paso 1 (_hasPassedStep1) o si la actividad ya
      // tenía startedAt (de sesión anterior), usar esa hora; si no hay ninguna,
      // usar now como fallback para no dejar startedAt nulo al promover.
      final resolvedStartedAt = horaInicio != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              horaInicio!.hour,
              horaInicio!.minute,
            )
          : (existing?.startedAt ??
                activity.horaInicio ??
                (_hasPassedStep1 ? now : null));
      final resolvedFinishedAt = horaFin != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              horaFin!.hour,
              horaFin!.minute,
            )
          : (existing?.finishedAt ?? activity.horaFin);

      // Preserve terminal/in-progress lifecycle states during autosave.
      final existingStatus = (existing?.status ?? '').trim().toUpperCase();
      // Promover SYNCED → REVISION_PENDIENTE si:
      // - el usuario pasó la validación del paso 1 en esta sesión, O
      // - la actividad ya tenía startedAt (sesión anterior o swipe previo)
      // pero NO si ya está terminada (finishedAt != null).
      final shouldPromoteSynced =
          (_hasPassedStep1 ||
              (existing != null && existing.startedAt != null)) &&
          (existing?.finishedAt == null);
      final saveStatus = switch (existingStatus) {
        'READY_TO_SYNC' => 'READY_TO_SYNC',
        'SYNCED' => shouldPromoteSynced ? 'REVISION_PENDIENTE' : 'SYNCED',
        'REVISION_PENDIENTE' => 'REVISION_PENDIENTE',
        'ERROR' => 'ERROR',
        _ => 'DRAFT',
      };

      final companion = ActivitiesCompanion.insert(
        id: activityId,
        projectId: resolvedProjectId,
        activityTypeId: resolvedTypeId,
        segmentId: drift.Value(
          selectedFrontId?.trim().isNotEmpty == true
              ? selectedFrontId!.trim()
              : null,
        ),
        title: activity.title.isNotEmpty ? activity.title : 'Actividad',
        description: drift.Value(descText.isNotEmpty ? descText : null),
        pk: drift.Value(pkInicio ?? existing?.pk ?? activity.pk),
        pkRefType: drift.Value(
          existing?.pkRefType ??
              switch (tipoUbicacion) {
                TipoUbicacion.puntual => 'PK',
                TipoUbicacion.tramo => 'TRAMO',
                TipoUbicacion.general => 'GENERAL',
              },
        ),
        createdAt: existing?.createdAt ?? now,
        createdByUserId: currentUserId,
        assignedToUserId: drift.Value(resolvedAssignedToUserId),
        status: drift.Value(saveStatus),
        startedAt: drift.Value(resolvedStartedAt),
        finishedAt: drift.Value(resolvedFinishedAt),
        geoLat: drift.Value(geoLat),
        geoLon: drift.Value(geoLon),
        geoAccuracy: drift.Value(geoAccuracy),
        catalogVersionId: drift.Value(catalogRepo.currentVersionId),
      );

      final existingSnapshot = await _loadExistingWizardPayloadSnapshot(
        activityId,
      );
      final fields = _buildDraftFields(
        activityId,
        existingSnapshot: existingSnapshot,
      );
      if (resolvedAssignedToUserId != null &&
          resolvedAssignedToUserId.trim().isNotEmpty) {
        final alreadyPresent = fields.any(
          (c) => c.fieldKey.value == 'assignee_user_id',
        );
        if (!alreadyPresent) {
          fields.add(
            ActivityFieldsCompanion.insert(
              id: '$activityId:assignee_user_id',
              activityId: activityId,
              fieldKey: 'assignee_user_id',
              valueText: drift.Value(resolvedAssignedToUserId.trim()),
            ),
          );
        }
      }

      await dao.upsertActivityRow(companion);

      // Preservar verdad del servidor y, si el controller aún no trae estado útil,
      // también conservar el snapshot/datos previos del wizard para no vaciarlos.
      const _serverTruthKeys = {
        'assignee_user_id',
        'operational_state',
        'review_state',
        'next_action',
        'sync_state',
        'review_comment',
        'review_reject_reason_code',
        'wizard_payload_snapshot',
      };
      const _wizardDataKeys = {
        'risk_level',
        'activity_type',
        'subcategory',
        'subcategory_other_text',
        'purpose',
        'topics',
        'topic_other_text',
        'attendees',
        'attendee_representatives',
        'result',
        'report_notes',
        'report_agreements',
        'front_id',
        'front_name',
        'draft_project_id',
        'draft_project_code',
        'draft_project_name',
        'draft_estado',
        'draft_municipio',
        'draft_colonia',
        'draft_tipo_ubicacion',
        'draft_pk_inicio',
        'draft_pk_fin',
        'draft_hora_inicio',
        'draft_hora_fin',
        'origin',
        'unplanned_reason',
        'unplanned_reason_other_text',
        'unplanned_reference',
        'has_evidence',
      };
      final preserveWizardData = !_hasMeaningfulWizardState();
      final keysToPreserve = <String>{
        ..._serverTruthKeys,
        if (preserveWizardData) ..._wizardDataKeys,
      }.toList();
      final existingPreservedFields =
          await (database.select(database.activityFields)..where(
                (t) =>
                    t.activityId.equals(activityId) &
                    t.fieldKey.isIn(keysToPreserve),
              ))
              .get();
      for (final f in existingPreservedFields) {
        final alreadyPresent = fields.any(
          (c) => c.fieldKey.value == f.fieldKey,
        );
        if (!alreadyPresent) {
          fields.add(
            ActivityFieldsCompanion.insert(
              id: f.id,
              activityId: activityId,
              fieldKey: f.fieldKey,
              valueText: drift.Value(f.valueText),
              valueJson: drift.Value(f.valueJson),
            ),
          );
        }
      }

      await dao.replaceActivityFields(activityId, fields);
      await _saveEvidencesToDb(activityId);
      await _queuePendingEvidenceUploads(activityId);

      appLogger.d(
        'Draft saved: $activityId (${fields.length} fields, ${evidencias.length} evidencias)',
      );
    } catch (e, st) {
      appLogger.w('saveDraftSilently failed: $e', stackTrace: st);
    }
  }

  /// Marks the activity as incomplete capture after step 1 is completed,
  /// even when it was not explicitly started from Home.
  Future<void> markIncompleteCaptureAfterContextStep() async {
    try {
      await _ensureDraftActivity();

      final existing = await _dao.getActivityById(activity.id);
      if (existing == null) return;

      // Do not downgrade activities that were already finished.
      if (existing.finishedAt != null ||
          activity.executionState == ExecutionState.terminada) {
        return;
      }

      // Activar flag ANTES del await para que saveDraftSilently lo vea
      // incluso si la escritura en BD falla por algún motivo.
      _hasPassedStep1 = true;

      final now = DateTime.now();
      final resolvedStartedAt = horaInicio != null
          ? DateTime(
              now.year,
              now.month,
              now.day,
              horaInicio!.hour,
              horaInicio!.minute,
            )
          : (existing.startedAt ?? activity.horaInicio ?? now);

      await _dao.markActivityCaptureIncomplete(
        activityId: activity.id,
        startedAt: resolvedStartedAt,
      );
    } catch (e, st) {
      appLogger.w(
        'markIncompleteCaptureAfterContextStep failed: $e',
        stackTrace: st,
      );
    }
  }

  bool _hasMeaningfulWizardState() {
    return risk != null ||
        _selectedSubcategory != null ||
        _selectedPurpose != null ||
        selectedTopicIds.isNotEmpty ||
        selectedAttendeeIds.isNotEmpty ||
        selectedResult != null ||
        reportNotes.trim().isNotEmpty ||
        reportAgreements.any((item) => item.trim().isNotEmpty) ||
        otherSubcategoryText.trim().isNotEmpty ||
        otherTopicText.trim().isNotEmpty ||
        evidencias.isNotEmpty;
  }

  List<ActivityFieldsCompanion> _buildDraftFields(
    String activityId, {
    Map<String, dynamic>? existingSnapshot,
  }) {
    final fields = <ActivityFieldsCompanion>[];

    void add(String key, {String? text, String? json}) {
      if (text == null && json == null) return;
      fields.add(
        ActivityFieldsCompanion.insert(
          id: _uuid.v4(),
          activityId: activityId,
          fieldKey: key,
          valueText: drift.Value(text),
          valueJson: drift.Value(json),
        ),
      );
    }

    if (risk != null) add('risk_level', text: risk!.name);
    if (_selectedActivity != null)
      add('activity_type', text: _selectedActivity!.id);
    if (_selectedSubcategory != null)
      add('subcategory', text: _selectedSubcategory!.id);
    if (isOtherSubcategory && otherSubcategoryText.trim().isNotEmpty) {
      add('subcategory_other_text', text: otherSubcategoryText.trim());
    }
    if (_selectedPurpose != null) add('purpose', text: _selectedPurpose!.id);
    if (selectedFrontId?.trim().isNotEmpty == true) {
      add('front_id', text: selectedFrontId!.trim());
    } else if (selectedFrontName.trim().isNotEmpty) {
      add('front_name', text: selectedFrontName.trim());
    }
    if (selectedProjectId?.trim().isNotEmpty == true) {
      add('draft_project_id', text: selectedProjectId!.trim());
    }
    if (selectedProjectCode.trim().isNotEmpty) {
      add('draft_project_code', text: selectedProjectCode.trim());
    }
    if (selectedProjectName.trim().isNotEmpty) {
      add('draft_project_name', text: selectedProjectName.trim());
    }
    if (estadoId?.trim().isNotEmpty == true) {
      add('draft_estado', text: estadoId!.trim());
    }
    if (municipioId?.trim().isNotEmpty == true) {
      add('draft_municipio', text: municipioId!.trim());
    }
    if (colonia.trim().isNotEmpty) {
      add('draft_colonia', text: colonia.trim());
    }
    add('draft_tipo_ubicacion', text: tipoUbicacion.name);
    if (pkInicio != null) {
      add('draft_pk_inicio', text: pkInicio.toString());
    }
    if (pkFin != null) {
      add('draft_pk_fin', text: pkFin.toString());
    }
    if (selectedTopicIds.isNotEmpty) {
      add('topics', json: jsonEncode(selectedTopicIds.toList()));
    }
    if (isOtherTopicSelected && otherTopicText.trim().isNotEmpty) {
      add('topic_other_text', text: otherTopicText.trim());
    }
    if (selectedAttendeeIds.isNotEmpty) {
      add('attendees', json: jsonEncode(selectedAttendeeIds.toList()));
    }
    if (attendeeRepresentatives.isNotEmpty) {
      add(
        'attendee_representatives',
        json: jsonEncode(attendeeRepresentatives),
      );
    }
    if (selectedResult != null) add('result', text: selectedResult!.id);
    if (reportNotes.trim().isNotEmpty)
      add('report_notes', text: reportNotes.trim());
    final cleanedAgreements = getReportAgreements();
    if (cleanedAgreements.isNotEmpty) {
      add('report_agreements', json: jsonEncode(cleanedAgreements));
    }
    if (horaInicio != null) {
      add(
        'draft_hora_inicio',
        text:
            '${horaInicio!.hour.toString().padLeft(2, '0')}:${horaInicio!.minute.toString().padLeft(2, '0')}',
      );
    }
    if (horaFin != null) {
      add(
        'draft_hora_fin',
        text:
            '${horaFin!.hour.toString().padLeft(2, '0')}:${horaFin!.minute.toString().padLeft(2, '0')}',
      );
    }
    if (isUnplanned) {
      add('origin', text: 'unplanned');
      if (unplannedReason != null)
        add('unplanned_reason', text: unplannedReason);
      if (unplannedReasonOtherText.trim().isNotEmpty) {
        add(
          'unplanned_reason_other_text',
          text: unplannedReasonOtherText.trim(),
        );
      }
      if (unplannedReference.trim().isNotEmpty) {
        add('unplanned_reference', text: unplannedReference.trim());
      }
    }
    add(
      'wizard_payload_snapshot',
      json: jsonEncode(
        _buildWizardPayloadForSync(existingSnapshot: existingSnapshot),
      ),
    );
    add('has_evidence', text: hasEvidence ? 'true' : 'false');
    return fields;
  }

  Future<void> _persistEvidenceDraftsForCurrentActivity({
    bool preserveExistingIfCurrentEmpty = true,
  }) async {
    try {
      await _ensureDraftActivity();
      await _saveEvidencesToDb(
        activity.id,
        preserveExistingIfCurrentEmpty: preserveExistingIfCurrentEmpty,
      );
    } catch (e, st) {
      appLogger.w('persistEvidenceDrafts failed: $e', stackTrace: st);
    }
  }

  /// Saves (or replaces) all in-memory evidencias to the evidences table.
  Future<void> _saveEvidencesToDb(
    String activityId, {
    bool preserveExistingIfCurrentEmpty = true,
  }) async {
    try {
      if (evidencias.isEmpty && preserveExistingIfCurrentEmpty) {
        final existingRows = await _dao.getEvidencesForActivity(activityId);
        if (existingRows.isNotEmpty) {
          return;
        }
      }

      await (database.delete(
        database.evidences,
      )..where((t) => t.activityId.equals(activityId))).go();
      for (final draft in evidencias) {
        await database
            .into(database.evidences)
            .insertOnConflictUpdate(
              EvidencesCompanion.insert(
                id: _uuid.v4(),
                activityId: activityId,
                type: 'PHOTO',
                filePathLocal: draft.localPath,
                takenAt: drift.Value(draft.createdAt),
                geoLat: drift.Value(draft.lat),
                geoLon: drift.Value(draft.lng),
                caption: drift.Value(
                  draft.descripcion.trim().isNotEmpty
                      ? draft.descripcion.trim()
                      : null,
                ),
              ),
            );
      }
    } catch (e) {
      appLogger.w('_saveEvidencesToDb error: $e');
    }
  }

  Future<void> _queuePendingEvidenceUploads(String activityId) async {
    try {
      final evidenceRows = await _dao.getEvidencesForActivity(activityId);
      if (evidenceRows.isEmpty) {
        return;
      }

      final existingQueueRows = await ((database.select(
        database.pendingUploads,
      )..where((t) => t.activityId.equals(activityId))).get());
      final queuedPaths = existingQueueRows
          .map((row) => row.localPath.trim().toLowerCase())
          .toSet();

      for (final evidence in evidenceRows) {
        final localPath = evidence.filePathLocal.trim();
        if (localPath.isEmpty) continue;

        final normalizedPath = localPath.toLowerCase();
        if (queuedPaths.contains(normalizedPath)) {
          continue;
        }

        final file = File(localPath);
        if (!await file.exists()) {
          appLogger.w(
            'Skipping pending upload; local evidence file is missing: $localPath',
          );
          continue;
        }

        final fileName = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'evidence.jpg';
        final lowerPath = localPath.toLowerCase();
        final mimeType = lowerPath.endsWith('.png')
            ? 'image/png'
            : lowerPath.endsWith('.pdf')
            ? 'application/pdf'
            : 'image/jpeg';

        await database
            .into(database.pendingUploads)
            .insert(
              PendingUploadsCompanion.insert(
                id: _uuid.v4(),
                activityId: activityId,
                localPath: localPath,
                fileName: fileName,
                mimeType: mimeType,
                sizeBytes: await file.length(),
                status: const drift.Value('PENDING_INIT'),
              ),
            );

        await (database.update(database.evidences)
              ..where((t) => t.id.equals(evidence.id)))
            .write(const EvidencesCompanion(status: drift.Value('QUEUED')));

        queuedPaths.add(normalizedPath);
      }
    } catch (e, st) {
      appLogger.w('queuePendingEvidenceUploads failed: $e', stackTrace: st);
    }
  }

  /// Adds the activity to sync_queue so SyncService can push it to the server.
  Future<void> _enqueueForSync(
    String activityId,
    ActivitiesCompanion companion,
  ) async {
    try {
      final dao = _dao;
      final activityTypeCode = await _resolveActivityTypeCodeForSync(
        companion.activityTypeId.value,
      );
      final now = DateTime.now();
      final assignedToUserId = await _resolveAssignedUserIdForSync(activityId);
      final pkStartForSync = companion.pk.value ?? pkInicio ?? activity.pk ?? 0;
      final pkEndForSync = tipoUbicacion == TipoUbicacion.tramo ? pkFin : null;
      final existingSnapshot = await _loadExistingWizardPayloadSnapshot(
        activityId,
      );
      final wizardPayload = _buildWizardPayloadForSync(
        existingSnapshot: existingSnapshot,
      );

      final dto = ActivityDTO(
        uuid: activityId,
        projectId: companion.projectId.value,
        frontId: companion.segmentId.value,
        pkStart: pkStartForSync,
        pkEnd: pkEndForSync,
        executionState: 'COMPLETADA',
        assignedToUserId: assignedToUserId,
        createdByUserId: companion.createdByUserId.value,
        catalogVersionId: companion.catalogVersionId.value ?? '',
        activityTypeCode: activityTypeCode,
        latitude: companion.geoLat.value?.toString(),
        longitude: companion.geoLon.value?.toString(),
        title: companion.title.value,
        description: companion.description.value,
        wizardPayload: wizardPayload,
        createdAt: companion.createdAt.value,
        updatedAt: now,
        syncVersion: 0,
      );

      await dao.markReadyToSync(
        activityId: activityId,
        userId: currentUserId,
        payload: dto.toJson(),
      );
    } catch (e) {
      appLogger.w('_enqueueForSync error: $e');
    }
  }

  Future<String> _resolveActivityTypeCodeForSync(String activityTypeId) async {
    final normalizedId = activityTypeId.trim();
    if (normalizedId.isEmpty) {
      return activityTypeId;
    }

    final row = await (database.select(
      database.catalogActivityTypes,
    )..where((t) => t.id.equals(normalizedId))).getSingleOrNull();
    final code = row?.code.trim();
    if (code != null && code.isNotEmpty) {
      return code;
    }

    // Fallback keeps prior behavior for legacy rows if catalog lookup is unavailable.
    return activityTypeId;
  }

  Map<String, dynamic> _buildWizardPayloadForSync({
    Map<String, dynamic>? existingSnapshot,
  }) {
    final topicItems = <Map<String, String>>[];
    for (final topicId in selectedTopicIds) {
      if (topicId == 'OTRO_TEMA') continue;
      final match = topics.cast<CatItem?>().firstWhere(
        (item) => item?.id == topicId,
        orElse: () => null,
      );
      topicItems.add({'id': topicId, 'name': (match?.name ?? topicId).trim()});
    }

    final attendeeItems = selectedAttendeeIds
        .map((id) {
          final attendee = attendeeById(id);
          return {
            'id': id,
            'name': (attendee?.name ?? id).trim(),
            'representative_name': attendeeRepresentative(id),
          };
        })
        .toList(growable: false);

    final evidenceItems = evidencias
        .where((draft) => draft.localPath.trim().isNotEmpty)
        .map((draft) => draft.toJson())
        .toList(growable: false);
    final persistedEvidenceItems =
        existingSnapshot == null || existingSnapshot['evidences'] is! List
        ? const <dynamic>[]
        : List<dynamic>.from(existingSnapshot['evidences'] as List);

    return {
      'risk_level': risk?.name,
      'activity': _selectedActivity == null
          ? null
          : {'id': _selectedActivity!.id, 'name': _selectedActivity!.name},
      'subcategory': _selectedSubcategory == null
          ? null
          : {
              'id': _selectedSubcategory!.id,
              'name': _selectedSubcategory!.name,
              'other_text': otherSubcategoryText.trim().isEmpty
                  ? null
                  : otherSubcategoryText.trim(),
            },
      'purpose': _selectedPurpose == null
          ? null
          : {'id': _selectedPurpose!.id, 'name': _selectedPurpose!.name},
      'topics': topicItems,
      'topic_other_text': otherTopicText.trim().isEmpty
          ? null
          : otherTopicText.trim(),
      'attendees': attendeeItems,
      'evidences': evidenceItems.isNotEmpty
          ? evidenceItems
          : persistedEvidenceItems,
      'result': selectedResult == null
          ? null
          : {'id': selectedResult!.id, 'name': selectedResult!.name},
      'notes': reportNotes.trim().isEmpty ? null : reportNotes.trim(),
      'agreements': getReportAgreements(),
      'location': {
        'tipo_ubicacion': tipoUbicacion.name,
        'pk_inicio': pkInicio,
        'pk_fin': pkFin,
        'pk_ref_type': switch (tipoUbicacion) {
          TipoUbicacion.puntual => 'PK',
          TipoUbicacion.tramo => 'TRAMO',
          TipoUbicacion.general => 'GENERAL',
        },
        'estado': estadoId,
        'municipio': municipioId,
        'colonia': colonia.trim().isEmpty ? null : colonia.trim(),
        'front_id': selectedFrontId,
        'front_name': selectedFrontName.trim().isEmpty
            ? null
            : selectedFrontName.trim(),
      },
      'unplanned': {
        'is_unplanned': isUnplanned,
        'reason': unplannedReason,
        'reason_other_text': unplannedReasonOtherText.trim().isEmpty
            ? null
            : unplannedReasonOtherText.trim(),
        'reference': unplannedReference.trim().isEmpty
            ? null
            : unplannedReference.trim(),
      },
    };
  }

  Future<String?> _resolveAssignedUserIdForSync(String activityId) async {
    final fromActivity = activity.assignedToUserId?.trim();
    if (fromActivity != null && fromActivity.isNotEmpty) {
      return fromActivity;
    }

    final assignment =
        await ((database.select(database.agendaAssignments)
              ..where(
                (t) =>
                    t.activityId.equals(activityId) | t.id.equals(activityId),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull());

    final fromAssignment = assignment?.resourceId.trim();
    if (fromAssignment != null && fromAssignment.isNotEmpty) {
      return fromAssignment;
    }

    return null;
  }

  Future<String?> _resolveProjectIdFromAssignment(String activityId) async {
    final assignment =
        await ((database.select(database.agendaAssignments)
              ..where(
                (t) =>
                    t.activityId.equals(activityId) | t.id.equals(activityId),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.updatedAt)])
              ..limit(1))
            .getSingleOrNull());
    final projectId = assignment?.projectId.trim();
    if (projectId == null || projectId.isEmpty) {
      return null;
    }
    return projectId;
  }

  /// Triggers a background sync push. Fire-and-forget — never throws.
  void _triggerBackgroundPush() {
    try {
      final syncService = GetIt.I<SyncService>();
      unawaited(syncService.pushPendingChanges());
    } catch (_) {
      // SyncService not available or offline — silently ignore
    }
  }

  String _buildDescription() {
    final parts = <String>[];

    if (_selectedActivity != null) {
      parts.add('Actividad: ${_selectedActivity!.name}');
    }
    if (_selectedSubcategory != null) {
      parts.add('Subcategoría: ${_selectedSubcategory!.name}');
    }
    if (_selectedPurpose != null) {
      parts.add('Propósito: ${_selectedPurpose!.name}');
    }

    final topicNames = <String>[];
    for (final topicId in selectedTopicIds) {
      if (topicId == 'OTRO_TEMA') continue;
      final match = topics.cast<CatItem?>().firstWhere(
        (item) => item?.id == topicId,
        orElse: () => null,
      );
      final topicName = (match?.name ?? topicId).trim();
      if (topicName.isNotEmpty) {
        topicNames.add(topicName);
      }
    }
    if (isOtherTopicSelected && otherTopicText.trim().isNotEmpty) {
      topicNames.add(otherTopicText.trim());
    }
    if (topicNames.isNotEmpty) {
      parts.add('Temas: ${topicNames.join(', ')}');
    }

    if (selectedResult != null) {
      parts.add('Resultado: ${selectedResult!.name}');
    }

    return parts.join(' | ');
  }

  (double, double)? _tryParseGpsLocation(String? gpsLocation) {
    final raw = gpsLocation?.trim();
    if (raw == null || raw.isEmpty) return null;

    final parts = raw.split(',');
    if (parts.length < 2) return null;

    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) return null;

    return (lat, lon);
  }
}
