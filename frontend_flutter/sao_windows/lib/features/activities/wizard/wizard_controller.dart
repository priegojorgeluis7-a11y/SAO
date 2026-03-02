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
import 'models/evidence_draft.dart';

enum RiskLevel { bajo, medio, alto, prioritario }
enum TipoUbicacion { puntual, tramo, general }

const _uuid = Uuid();

class WizardController extends ChangeNotifier {
  final TodayActivity activity;
  final String projectCode;
  final CatalogRepository catalogRepo;
  final PendingEvidenceStore pendingStore;
  final AppDb database;
  final String currentUserId; // Usuario que está creando la actividad

  WizardController({
    required this.activity,
    required this.projectCode,
    required this.catalogRepo,
    required this.pendingStore,
    required this.database,
    required this.currentUserId,
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

  // Paso 3: Evidencias (con descripción obligatoria)
  final List<EvidenceDraft> evidencias = [];
  bool get hasEvidence => evidencias.isNotEmpty;

  // =========================
  // Init
  // =========================
  Future<void> init() async {
    if (catalogRepo.isReady) {
      _postInitPreselect();
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    await catalogRepo.init();

    _postInitPreselect();

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
    
    // Pre-cargar ubicación desde la actividad
    if (activity.estado.isNotEmpty) {
      // Mapear nombre del estado a ID (simulado)
      if (activity.estado.toLowerCase().contains('chihuahua')) {
        estadoId = 'est_1';
      } else if (activity.estado.toLowerCase().contains('durango')) {
        estadoId = 'est_2';
      } else if (activity.estado.toLowerCase().contains('sinaloa')) {
        estadoId = 'est_3';
      } else if (activity.estado.toLowerCase().contains('guanajuato')) {
        estadoId = 'est_4';
      }
    }
    
    if (activity.municipio.isNotEmpty) {
      // Mapear nombre del municipio a ID (simulado)
      if (activity.municipio.toLowerCase().contains('apaseo')) {
        municipioId = 'mun_1';
      } else if (activity.municipio.toLowerCase().contains('celaya')) {
        municipioId = 'mun_2';
      } else if (activity.municipio.toLowerCase().contains('cortazar')) {
        municipioId = 'mun_3';
      }
    }
    
    // Pre-cargar PK desde la actividad
    if (activity.pk != null) {
      pkInicio = activity.pk;
      tipoUbicacion = TipoUbicacion.puntual;
    }
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
    if (a == null || s == null) return const [];
    return catalogRepo.purposesFor(s, activityId: a);
  }

  List<CatItem> get topics => catalogRepo.temas;

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
    estadoId = estado;
    municipioId = null; // Reset cascada
    colonia = '';
    notifyListeners();
  }

  void setMunicipio(String? municipio) {
    municipioId = municipio;
    notifyListeners();
  }

  void setColonia(String value) {
    colonia = value;
    notifyListeners();
  }

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

    return true;
  }

  bool get canSave => canContinueFromFields;

  // =========================
  // Validación Reactiva ("Encuéntralo por mí")
  // =========================
  
  /// Valida el paso de contexto y retorna errores específicos
  ValidationResult validateContextStep() {
    final errors = <ValidationError>[];

    if (risk == null) {
      errors.add(ValidationError(
        fieldKey: 'risk',
        message: 'Selecciona el nivel de riesgo',
        step: 'context',
      ));
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

    return errors.isEmpty 
        ? ValidationResult.valid() 
        : ValidationResult.invalid(errors);
  }

  /// Valida que haya evidencia cargada
  ValidationResult validateEvidenceStep() {
    final errors = <ValidationError>[];

    if (!hasEvidence) {
      errors.add(ValidationError(
        fieldKey: 'evidence',
        message: 'Agrega al menos una evidencia (foto, PDF, etc.)',
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
    // PRIORIDAD 1: Evidencia
    if (evidencias.isEmpty) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Debes adjuntar al menos una foto de evidencia.',
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

    // PRIORIDAD 4: Riesgo
    if (risk == null) {
      return GatekeeperResult(
        isValid: false,
        errorMessage: 'Selecciona el nivel de riesgo.',
        errorFieldKey: 'risk',
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
  // Inferencia mock
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
    required String projectId,
    required String activityTypeId,
    String? segmentId,
    int? pk,
    String? pkRefType,
  }) async {
    try {
      final activityId = _uuid.v4();
      final now = DateTime.now();

      // Preparar datos de la actividad principal
      final activityCompanion = ActivitiesCompanion.insert(
        id: activityId,
        projectId: projectId,
        segmentId: drift.Value(segmentId),
        activityTypeId: activityTypeId,
        title: activity.title,
        description: drift.Value(_buildDescription()),
        pk: drift.Value(pk),
        pkRefType: drift.Value(pkRefType),
        createdAt: now,
        createdByUserId: currentUserId,
        status: const drift.Value('DRAFT'),
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
      ];

      // Guardar en DB usando el DAO
      final dao = ActivityDao(database);
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
}
