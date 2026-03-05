// lib/features/activities/wizard/wizard_controller.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../../core/utils/logger.dart';
import '../../home/models/today_activity.dart';
import '../../catalog/catalog_repository.dart';
import '../../evidence/pending_evidence_store.dart';
import 'wizard_validation.dart';
import 'validation/unplanned_validation.dart' as unplanned_val;
import 'models/evidence_draft.dart';

enum RiskLevel { bajo, medio, alto, prioritario }
enum TipoUbicacion { puntual, tramo, general }

const _uuid = Uuid();

class ProjectRef {
  final String id;
  final String code;
  final String name;

  const ProjectRef({
    required this.id,
    required this.code,
    required this.name,
  });
}

class FrontRef {
  final String id;
  final String name;

  const FrontRef({
    required this.id,
    required this.name,
  });
}

class WizardController extends ChangeNotifier {
  final TodayActivity activity;
  final String projectCode;
  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;
  final AppDb database;
  final String currentUserId; // Usuario que está creando la actividad
  final bool isUnplanned; // true → modo actividad no planeada

  WizardController({
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
    required this.database,
    required this.currentUserId,
    this.isUnplanned = false,
  });

  bool loading = true;

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
  int? pkFin;    // Solo para tramos
  
  RiskLevel? risk;

  // Paso 2: Clasificación
  CatItem? _selectedActivity;
  CatItem? _selectedSubcategory;
  CatItem? _selectedPurpose;

  String otherSubcategoryText = '';
  final Set<String> selectedTopicIds = {};
  String otherTopicText = '';
  final Set<String> selectedAttendeeIds = {};

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
    if (catalogRepo.isReady) {
      _postInitPreselect();
      await _loadContextOptions();
      await _rehydrateContextFields();
      await _rehydrateReportFields();
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    await catalogRepo.init(projectId: selectedProjectId ?? projectCode);

    _postInitPreselect();
    await _loadContextOptions();
    await _rehydrateContextFields();
    await _rehydrateReportFields();

    loading = false;
    notifyListeners();
  }

  void _postInitPreselect() {
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
    if (activity.pk != null) {
      pkInicio = activity.pk;
      tipoUbicacion = TipoUbicacion.puntual;
    }

    final initialGps = _tryParseGpsLocation(activity.gpsLocation);
    if (initialGps != null) {
      geoLat = initialGps.$1;
      geoLon = initialGps.$2;
    }

    selectedProjectId = projectCode;
    selectedProjectCode = projectCode;
    selectedProjectName = projectCode;
    selectedFrontName = activity.frente;
  }

  static const List<ProjectRef> _fallbackProjects = [
    ProjectRef(id: 'TMQ', code: 'TMQ', name: 'Tren México–Querétaro'),
    ProjectRef(id: 'TAP', code: 'TAP', name: 'Tren AIFA–Pachuca'),
    ProjectRef(id: 'TQI', code: 'TQI', name: 'Tren Querétaro–Irapuato'),
    ProjectRef(id: 'TSNL', code: 'TSNL', name: 'Tren Saltillo–Nuevo Laredo'),
  ];

  List<ProjectRef> get availableProjects => List.unmodifiable(_availableProjects);
  List<FrontRef> get availableFronts => List.unmodifiable(_availableFronts);
  List<String> get availableStates => List.unmodifiable(_availableStates);
  List<String> get availableMunicipios => List.unmodifiable(_availableMunicipios);

  String get contextProjectLabel {
    if (selectedProjectName.trim().isNotEmpty) return selectedProjectName.trim();
    if (selectedProjectCode.trim().isNotEmpty) return selectedProjectCode.trim();
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
    final dao = ActivityDao(database);

    try {
      final projects = await dao.listActiveProjects();
      _availableProjects = projects.isNotEmpty
          ? projects
              .map((p) => ProjectRef(id: p.id, code: p.code, name: p.name))
              .toList()
          : _fallbackProjects;
    } catch (_) {
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

    await loadFrontOptionsForProject(selectedProjectId ?? projectCode, notify: false);
    await loadLocationOptionsForProject(selectedProjectId ?? projectCode, notify: false);
  }

  Future<void> loadFrontOptionsForProject(String projectCodeOrId, {bool notify = true}) async {
    final dao = ActivityDao(database);
    try {
      final remoteFronts = await catalogRepo.fetchFrontsForProject(projectCodeOrId);
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
    } catch (_) {
      _availableFronts = const [];
    }

    final currentFrontExists = selectedFrontId != null &&
        _availableFronts.any((front) => front.id == selectedFrontId);
    if (!currentFrontExists) {
      selectedFrontId = null;
      if (selectedFrontName.trim().isEmpty) {
        selectedFrontName = activity.frente;
      }
    }

    if (notify) notifyListeners();
  }

  Future<void> loadLocationOptionsForProject(String projectCodeOrId, {bool notify = true}) async {
    try {
      _availableStates = await catalogRepo.fetchStatesForProject(projectCodeOrId);
    } catch (_) {
      _availableStates = const [];
    }

    final currentEstado = (estadoId ?? '').trim();
    if (currentEstado.isNotEmpty && _availableStates.contains(currentEstado)) {
      await loadMunicipiosForCurrentState(projectCodeOrId, currentEstado, notify: false);
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
      _availableMunicipios = await catalogRepo.fetchMunicipiosForProject(projectCodeOrId, estado);
    } catch (_) {
      _availableMunicipios = const [];
    }

    final currentMunicipio = (municipioId ?? '').trim();
    if (currentMunicipio.isNotEmpty && !_availableMunicipios.contains(currentMunicipio)) {
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

  List<CatItem> get attendeesInstitutional => catalogRepo.asistentesInstitucionales;
  List<CatItem> get attendeesLocal => catalogRepo.asistentesLocales;

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
    } else {
      selectedAttendeeIds.add(id);
    }
    notifyListeners();
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

  List<String> getReportAgreements() => sanitizeReportAgreements(reportAgreements);

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
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= evidencias.length) return;
    evidencias.removeAt(index);
    notifyListeners();
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
    await loadMunicipiosForCurrentState(selectedProjectId ?? projectCode, current, notify: true);
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
    catalogRepo.loadProjectBundle(project.id);
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
    unplannedReason = (normalized == null || normalized.isEmpty) ? null : normalized;
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
  bool get selectedActivityRequiresGeo => _selectedActivity?.requiresGeo ?? false;
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

    if (isUnplanned && (selectedProjectId == null || selectedProjectId!.trim().isEmpty)) {
      errors.add(ValidationError(
        fieldKey: 'project',
        message: 'Selecciona el proyecto para la actividad no planeada',
        step: 'context',
      ));
    }

    if (risk == null) {
      errors.add(ValidationError(
        fieldKey: 'risk',
        message: 'Selecciona el nivel de riesgo',
        step: 'context',
      ));
    }

    if (selectedActivityRequiresGeo && !hasValidGpsCoordinates) {
      errors.add(ValidationError(
        fieldKey: 'gps_required',
        message: 'No se pudo obtener ubicación GPS. Activa el GPS y vuelve a intentar.',
        step: 'context',
      ));
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
      errors.add(ValidationError(
        fieldKey: 'risk',
        message: 'Selecciona el nivel de riesgo',
        step: 'fields',
      ));
    }

    // Actividad
    if (_selectedActivity == null) {
      errors.add(ValidationError(
        fieldKey: 'activity',
        message: 'Selecciona una actividad principal',
        step: 'fields',
      ));
    }

    // Subcategoría
    if (_selectedSubcategory == null) {
      errors.add(ValidationError(
        fieldKey: 'subcategory',
        message: 'Selecciona una subcategoría',
        step: 'fields',
      ));
    } else if (isOtherSubcategory && otherSubcategoryText.trim().isEmpty) {
      errors.add(ValidationError(
        fieldKey: 'subcategory_other',
        message: 'Escribe el nombre de la nueva subcategoría',
        step: 'fields',
      ));
    }

    // Propósito (solo si hay propósitos disponibles)
    final purposes = availablePurposes;
    if (purposes.isNotEmpty && _selectedPurpose == null) {
      errors.add(ValidationError(
        fieldKey: 'purpose',
        message: 'Selecciona un propósito',
        step: 'fields',
      ));
    }

    // Temas (validar si se seleccionó "Otro tema" pero no escribió)
    if (isOtherTopicSelected && otherTopicText.trim().isEmpty) {
      errors.add(ValidationError(
        fieldKey: 'topic_other',
        message: 'Escribe el nombre del tema personalizado',
        step: 'fields',
      ));
    }

    // Resultado
    if (selectedResult == null) {
      errors.add(ValidationError(
        fieldKey: 'result',
        message: 'Selecciona un resultado',
        step: 'fields',
      ));
    }

    if (reportAgreements.any((item) => item.trim().isEmpty)) {
      errors.add(ValidationError(
        fieldKey: 'report_agreements',
        message: 'Completa o elimina acuerdos vacíos',
        step: 'fields',
      ));
    }

    return errors.isEmpty 
        ? ValidationResult.valid() 
        : ValidationResult.invalid(errors);
  }

  /// Valida que haya evidencia cargada
  ValidationResult validateEvidenceStep() {
    final errors = <ValidationError>[];

    if (evidencias.length < minimumEvidencePhotosRequired) {
      errors.add(ValidationError(
        fieldKey: 'evidence',
        message: 'Agrega al menos $minimumEvidencePhotosRequired evidencia(s).',
        step: 'evidence',
      ));
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
        if (isUnplanned && (selectedProjectId == null || selectedProjectId!.trim().isEmpty)) {
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
        errorMessage: 'Debes adjuntar al menos $minimumEvidencePhotosRequired foto(s) de evidencia.',
        errorFieldKey: 'btn_agregar_foto',
        step: 2, // Paso de evidencia (0-indexed)
      );
    }

    // Buscar primera foto sin descripción
    final indexSinDescripcion = evidencias.indexWhere((e) => !e.isValid);
    if (indexSinDescripcion != -1) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Falta descripción en la foto ${indexSinDescripcion + 1}.',
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
        errorMessage: 'No se pudo obtener ubicación GPS. Activa el GPS y vuelve a intentar.',
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
    if (t.contains('reunión') || t.contains('reunion')) return find('REU') ?? list.first;
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
  }) async {
    try {
      final dao = ActivityDao(database);
      final hasExistingActivity = await dao.activityExists(activity.id);
      final activityId = hasExistingActivity ? activity.id : _uuid.v4();
      final now = DateTime.now();
      final cleanedNotes = getReportNotes();
      final cleanedAgreements = getReportAgreements();

      final selectedActivityId = _selectedActivity?.id;
      if (selectedActivityId == null || selectedActivityId.trim().isEmpty) {
        throw StateError('No activity selected from effective catalog');
      }

      final selectedActivityName = _selectedActivity?.name.trim();
      final resolvedTitle = (selectedActivityName != null && selectedActivityName.isNotEmpty)
          ? selectedActivityName
          : activity.title.trim();

      final requestedProjectId = (projectId?.trim().isNotEmpty ?? false)
          ? projectId!.trim()
          : ((selectedProjectId?.trim().isNotEmpty ?? false)
            ? selectedProjectId!.trim()
            : projectCode);
      final requestedActivityTypeId = (activityTypeId?.trim().isNotEmpty ?? false)
          ? activityTypeId!.trim()
          : selectedActivityId.trim();
        final selectedSegmentId = (selectedFrontId?.trim().isNotEmpty ?? false)
          ? selectedFrontId!.trim()
          : null;
        final requestedSegmentId = (segmentId?.trim().isNotEmpty ?? false)
          ? segmentId!.trim()
          : selectedSegmentId;

      var resolvedProjectId = await dao.resolveProjectId(requestedProjectId);
      var resolvedActivityTypeId = await dao.resolveActivityTypeId(requestedActivityTypeId);

        if (hasExistingActivity && !isUnplanned) {
        final existing = await dao.getActivityById(activity.id);
        if (existing != null) {
          resolvedProjectId = existing.projectId;
          resolvedActivityTypeId = existing.activityTypeId;
        }
      }

      // Preparar datos de la actividad principal
      final activityCompanion = ActivitiesCompanion.insert(
        id: activityId,
        projectId: resolvedProjectId,
        segmentId: drift.Value(requestedSegmentId),
        activityTypeId: resolvedActivityTypeId,
        title: resolvedTitle,
        description: drift.Value(_buildDescription()),
        pk: drift.Value(pk),
        pkRefType: drift.Value(pkRefType),
        createdAt: now,
        createdByUserId: currentUserId,
        status: drift.Value(isUnplanned ? 'REVISION_PENDIENTE' : 'DRAFT'),
        geoLat: drift.Value(geoLat),
        geoLon: drift.Value(geoLon),
        geoAccuracy: drift.Value(geoAccuracy),
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
      await dao.upsertDraft(
        activity: activityCompanion,
        fields: fields,
      );

      appLogger.i('Actividad guardada exitosamente: $activityId');
      return activityId;
      
    } catch (e, stack) {
      appLogger.e('Error guardando actividad', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _rehydrateReportFields() async {
    final dao = ActivityDao(database);
    final fields = await dao.getFieldsByKey(activity.id);

    final notesField = fields['report_notes'];
    if (notesField?.valueText != null) {
      reportNotes = notesField!.valueText!;
    }

    final agreementsField = fields['report_agreements'];
    if (agreementsField?.valueJson != null && agreementsField!.valueJson!.trim().isNotEmpty) {
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
    final dao = ActivityDao(database);
    final fields = await dao.getFieldsByKey(activity.id);
    final existingActivity = await dao.getActivityById(activity.id);

    if (existingActivity != null && !hasValidGpsCoordinates) {
      geoLat = existingActivity.geoLat;
      geoLon = existingActivity.geoLon;
      geoAccuracy = existingActivity.geoAccuracy;
    }

    final frontIdField = fields['front_id'];
    if (frontIdField?.valueText != null && frontIdField!.valueText!.trim().isNotEmpty) {
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
    if (frontNameField?.valueText != null && frontNameField!.valueText!.trim().isNotEmpty) {
      selectedFrontName = frontNameField.valueText!.trim();
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
    if (risk != null) {
      parts.add('Riesgo: ${risk!.name.toUpperCase()}');
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
