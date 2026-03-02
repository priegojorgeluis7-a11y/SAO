import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Catálogos DATA-DRIVEN.
/// Carga desde JSON base (assets/catalogos.json) + items personalizados (archivo local).
class CatalogRepository {
  CatalogRepository();

  bool _ready = false;
  bool get isReady => _ready;

  CatalogData _data = CatalogData.fromJson({});
  CatalogData get data => _data;

  // Items personalizados agregados por el usuario
  CustomCatalogData _customData = CustomCatalogData.empty();

  // Items candidatos pendientes de aprobación del administrador
  List<CandidateItem> _pendingCandidates = [];

  /// Carga desde assets si existe (assets/catalogos.json).
  /// También carga items personalizados desde archivo local.
  Future<void> init() async {
    if (_ready) return;

    try {
      final raw = await rootBundle.loadString('assets/catalogos.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _data = CatalogData.fromJson(map);
    } catch (_) {
      // No local asset — data stays empty until catalog is synced from API
    }

    // Cargar items personalizados
    await _loadCustomData();
    await _loadPendingCandidates();

    _ready = true;
  }

  /// Carga items personalizados desde archivo local
  Future<void> _loadCustomData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_catalog_items.json');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _customData = CustomCatalogData.fromJson(json);
      }
    } catch (_) {
      _customData = CustomCatalogData.empty();
    }
  }

  /// Guarda items personalizados en archivo local
  Future<void> _saveCustomData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/custom_catalog_items.json');
      
      final json = _customData.toJson();
      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Silently fail
    }
  }

  /// Carga candidatos pendientes de aprobación
  Future<void> _loadPendingCandidates() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_candidates.json');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final items = (json['candidates'] as List?)
            ?.map((e) => CandidateItem.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _pendingCandidates = items;
      }
    } catch (_) {
      _pendingCandidates = [];
    }
  }

  /// Guarda candidatos pendientes
  Future<void> _savePendingCandidates() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_candidates.json');
      
      final json = {
        'candidates': _pendingCandidates.map((c) => c.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(json));
    } catch (_) {
      // Silently fail
    }
  }

  // =========================
  // Queries (helpers para Wizard)
  // =========================
  List<CatItem> get activities => [
    ..._data.actividades,
    ..._customData.customActivities,
  ];

  List<CatItem> subcatsFor(String activityId) {
    final normalizedActivityId = activityId.trim();
    final base = _lookupMapList(_data.subcategoriasByActividad, normalizedActivityId);
    final custom = _lookupMapList(_customData.customSubcategories, normalizedActivityId);
    return [...base, ...custom];
  }

  List<CatItem> purposesFor(String subcatId, {String? activityId}) {
    final normalizedSubcatId = subcatId.trim();

    final baseBySubcat = _lookupMapList(_data.propositosBySubcat, normalizedSubcatId);
    final customBySubcat = _lookupMapList(_customData.customPurposes, normalizedSubcatId);

    // Compatibilidad con catálogos donde el propósito viene relacionado por actividad
    // y subcategoría con key compuesta: ACTIVITY_ID|SUBCATEGORY_ID o ACTIVITY_ID|
    final normalizedActivityId = activityId?.trim();
    final baseByActivity = normalizedActivityId == null || normalizedActivityId.isEmpty
        ? const <CatItem>[]
        : [
            ..._lookupMapList(_data.propositosBySubcat, '$normalizedActivityId|$normalizedSubcatId'),
            ..._lookupMapList(_data.propositosBySubcat, '$normalizedActivityId|'),
          ];

    final merged = <String, CatItem>{
      for (final item in [
        ...baseBySubcat,
        ...baseByActivity,
        ...customBySubcat,
      ])
        item.id: item,
    };
    return merged.values.toList();
  }

  List<CatItem> temasSugeridosFor(String activityId) {
    final normalizedActivityId = activityId.trim();
    final ids = _lookupMapList(
      _data.temasSugeridosIdsByActividad,
      normalizedActivityId,
    );
    final allTopics = temas;
    final map = {for (final t in allTopics) t.id: t};
    return [for (final id in ids) if (map[id] != null) map[id]!];
  }

  List<TValue> _lookupMapList<TValue>(Map<String, List<TValue>> source, String key) {
    final exact = source[key];
    if (exact != null) return exact;

    for (final entry in source.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        return entry.value;
      }
    }
    return const [];
  }

  List<CatItem> get temas => [
    ..._data.temas,
    ..._customData.customTopics,
  ];

  List<CatItem> get asistentesInstitucionales => [
    ..._data.asistentesInstitucionales,
    ..._customData.customAttendeesInstitutional,
  ];
  
  List<CatItem> get asistentesLocales => [
    ..._data.asistentesLocales,
    ..._customData.customAttendeesLocal,
  ];

  List<CatItem> get resultados => _data.resultados;

  List<String> get matrizRiesgo => _data.matrizRiesgo;

  // =========================
  // Métodos para agregar items personalizados
  // =========================
  
  /// Agrega una nueva actividad personalizada
  Future<void> addCustomActivity(String name) async {
    final id = 'CUSTOM_ACT_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.category_rounded);
    _customData.customActivities.add(item);
    await _saveCustomData();
  }

  /// Agrega una nueva subcategoría personalizada para una actividad
  Future<void> addCustomSubcategory(String activityId, String name) async {
    final id = 'CUSTOM_SUB_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.subdirectory_arrow_right_rounded);
    
    if (!_customData.customSubcategories.containsKey(activityId)) {
      _customData.customSubcategories[activityId] = [];
    }
    _customData.customSubcategories[activityId]!.add(item);
    await _saveCustomData();
  }

  /// Agrega un nuevo propósito personalizado para una subcategoría
  Future<void> addCustomPurpose(String subcategoryId, String name) async {
    final id = 'CUSTOM_PUR_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.flag_rounded);
    
    if (!_customData.customPurposes.containsKey(subcategoryId)) {
      _customData.customPurposes[subcategoryId] = [];
    }
    _customData.customPurposes[subcategoryId]!.add(item);
    await _saveCustomData();
  }

  /// Agrega un nuevo tema personalizado
  Future<void> addCustomTopic(String name) async {
    final id = 'CUSTOM_TOP_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.local_offer_rounded);
    _customData.customTopics.add(item);
    await _saveCustomData();
  }

  /// Agrega un nuevo asistente institucional personalizado
  Future<void> addCustomAttendeeInstitutional(String name) async {
    final id = 'CUSTOM_ATT_INST_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.apartment_rounded);
    _customData.customAttendeesInstitutional.add(item);
    await _saveCustomData();
  }

  /// Agrega un nuevo asistente local personalizado
  Future<void> addCustomAttendeeLocal(String name) async {
    final id = 'CUSTOM_ATT_LOC_${DateTime.now().millisecondsSinceEpoch}';
    final item = CatItem(id: id, label: name, icon: Icons.groups_rounded);
    _customData.customAttendeesLocal.add(item);
    await _saveCustomData();
  }

  // =========================
  // Sistema de Candidatos (Para aprobación del Admin)
  // =========================

  /// Registra un nuevo candidato pendiente de aprobación
  /// Usado cuando el usuario selecciona "guardar solo para esta actividad"
  Future<void> addCandidate({
    required String type, // 'activity', 'subcategory', 'purpose', 'topic', 'attendee_inst', 'attendee_local'
    required String name,
    String? parentId, // ID del padre (ej. activityId para subcategoría)
    String? reportId, // ID del reporte que originó el candidato
    String? userId, // ID del usuario que lo propuso
  }) async {
    final candidate = CandidateItem(
      id: 'CAND_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      name: name,
      parentId: parentId,
      reportId: reportId,
      userId: userId,
      proposedAt: DateTime.now(),
      status: CandidateStatus.pending,
    );
    
    _pendingCandidates.add(candidate);
    await _savePendingCandidates();
  }

  /// Obtiene todos los candidatos pendientes (para pantalla de admin)
  List<CandidateItem> get pendingCandidates => 
      _pendingCandidates.where((c) => c.status == CandidateStatus.pending).toList();

  /// Aprueba un candidato y lo agrega al catálogo permanente
  Future<void> approveCandidate(String candidateId) async {
    final candidate = _pendingCandidates.firstWhere((c) => c.id == candidateId);
    
    // Agregar al catálogo permanente según el tipo
    switch (candidate.type) {
      case 'activity':
        await addCustomActivity(candidate.name);
        break;
      case 'subcategory':
        if (candidate.parentId != null) {
          await addCustomSubcategory(candidate.parentId!, candidate.name);
        }
        break;
      case 'purpose':
        if (candidate.parentId != null) {
          await addCustomPurpose(candidate.parentId!, candidate.name);
        }
        break;
      case 'topic':
        await addCustomTopic(candidate.name);
        break;
      case 'attendee_inst':
        await addCustomAttendeeInstitutional(candidate.name);
        break;
      case 'attendee_local':
        await addCustomAttendeeLocal(candidate.name);
        break;
    }
    
    // Marcar como aprobado
    candidate.status = CandidateStatus.approved;
    candidate.reviewedAt = DateTime.now();
    await _savePendingCandidates();
  }

  /// Rechaza un candidato
  Future<void> rejectCandidate(String candidateId, {String? reason}) async {
    final candidate = _pendingCandidates.firstWhere((c) => c.id == candidateId);
    candidate.status = CandidateStatus.rejected;
    candidate.reviewedAt = DateTime.now();
    candidate.rejectionReason = reason;
    await _savePendingCandidates();
  }
}

class CatalogData {
  final String version;
  final List<CatItem> actividades;

  final Map<String, List<CatItem>> subcategoriasByActividad;
  final Map<String, List<CatItem>> propositosBySubcat;

  final List<CatItem> temas;
  final Map<String, List<String>> temasSugeridosIdsByActividad;

  final List<CatItem> asistentesInstitucionales;
  final List<CatItem> asistentesLocales;

  final List<CatItem> resultados;

  final List<String> matrizRiesgo;

  CatalogData({
    required this.version,
    required this.actividades,
    required this.subcategoriasByActividad,
    required this.propositosBySubcat,
    required this.temas,
    required this.temasSugeridosIdsByActividad,
    required this.asistentesInstitucionales,
    required this.asistentesLocales,
    required this.resultados,
    required this.matrizRiesgo,
  });

  factory CatalogData.fromJson(Map<String, dynamic> json) {
    List<CatItem> parseItems(List<dynamic> arr, {IconData fallback = Icons.list_alt_rounded}) {
      return arr.map((e) {
        final m = e as Map<String, dynamic>;
        return CatItem(
          id: (m['id'] ?? m['activity_id'] ?? m['subcategory_id'] ?? m['topic_id'] ?? '').toString(),
          label: (m['name_effective'] ?? m['name'] ?? m['nombre'] ?? m['label'] ?? '').toString(),
          icon: fallback,
        );
      }).toList();
    }

    // Activities
    final actividades = parseItems((json['activities'] ?? <dynamic>[]) as List<dynamic>, fallback: Icons.category_rounded);

    // Subcategorias (por actividad)
    final Map<String, List<CatItem>> subcatsByAct = {};
    final subcatsJson = json['subcategoriesByActivity'] as Map<String, dynamic>?;
    if (subcatsJson != null) {
      for (final entry in subcatsJson.entries) {
        final actId = entry.key;
        final subs = (entry.value as List?) ?? [];
        subcatsByAct[actId] = parseItems(subs, fallback: Icons.subdirectory_arrow_right_rounded);
      }
    }

    // Compatibilidad: subcategorías planas con activity_id
    final subcategoriesFlat = (json['subcategories'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    for (final item in subcategoriesFlat) {
      if (item is! Map<String, dynamic>) continue;
      final activityId = (item['activity_id'] ?? '').toString();
      final subcatId = (item['id'] ?? item['subcategory_id'] ?? '').toString();
      final name = (item['name_effective'] ?? item['name'] ?? item['nombre'] ?? item['label'] ?? '').toString();
      if (activityId.isEmpty || subcatId.isEmpty || name.isEmpty) continue;

      final catItem = CatItem(
        id: subcatId,
        label: name,
        icon: Icons.subdirectory_arrow_right_rounded,
      );
      subcatsByAct.putIfAbsent(activityId, () => []);
      if (!subcatsByAct[activityId]!.any((x) => x.id == catItem.id)) {
        subcatsByAct[activityId]!.add(catItem);
      }
    }

    // Propósitos (por subcategoría)
    final Map<String, List<CatItem>> purposesBySub = {};
    final purposesJson = json['purposesBySubcategory'] as Map<String, dynamic>?;
    if (purposesJson != null) {
      for (final entry in purposesJson.entries) {
        final subcatId = entry.key;
        final purposes = (entry.value as List?) ?? [];
        purposesBySub[subcatId] = parseItems(purposes, fallback: Icons.flag_rounded);
      }
    }

    // Compatibilidad: propósitos planos con activity_id + subcategory_id
    final purposesFlat = (json['purposes'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    for (final item in purposesFlat) {
      if (item is! Map<String, dynamic>) continue;
      final purposeId = (item['id'] ?? '').toString();
      final activityId = (item['activity_id'] ?? '').toString();
      final subcategoryId = (item['subcategory_id'] ?? '').toString();
      final name = (item['name_effective'] ?? item['name'] ?? item['nombre'] ?? item['label'] ?? '').toString();
      if (purposeId.isEmpty || name.isEmpty) continue;

      final purposeItem = CatItem(
        id: purposeId,
        label: name,
        icon: Icons.flag_rounded,
      );

      // Clave primaria por subcategoría (comportamiento actual)
      if (subcategoryId.isNotEmpty) {
        purposesBySub.putIfAbsent(subcategoryId, () => []);
        if (!purposesBySub[subcategoryId]!.any((x) => x.id == purposeItem.id)) {
          purposesBySub[subcategoryId]!.add(purposeItem);
        }
      }

      // Clave compuesta para filtrar correcto por actividad
      if (activityId.isNotEmpty) {
        final compositeKey = '$activityId|$subcategoryId';
        purposesBySub.putIfAbsent(compositeKey, () => []);
        if (!purposesBySub[compositeKey]!.any((x) => x.id == purposeItem.id)) {
          purposesBySub[compositeKey]!.add(purposeItem);
        }

        // También soporta propósitos de actividad sin subcategoría específica
        if (subcategoryId.isEmpty) {
          final activityOnlyKey = '$activityId|';
          purposesBySub.putIfAbsent(activityOnlyKey, () => []);
          if (!purposesBySub[activityOnlyKey]!.any((x) => x.id == purposeItem.id)) {
            purposesBySub[activityOnlyKey]!.add(purposeItem);
          }
        }
      }
    }

    // Temas
    final temas = parseItems((json['topics'] ?? <dynamic>[]) as List<dynamic>, fallback: Icons.local_offer_rounded);

    // Temas sugeridos por actividad
    final Map<String, List<String>> sugeridos = {};
    final suggestedJson = json['suggestedTopicsByActivity'] as Map<String, dynamic>?;
    if (suggestedJson != null) {
      for (final entry in suggestedJson.entries) {
        final actId = entry.key;
        final ids = (entry.value as List?) ?? [];
        sugeridos[actId] = ids.map((x) => x.toString()).toList();
      }
    }

    // Compatibilidad: relaciones planas rel_activity_topics
    final relTopics = (json['rel_activity_topics'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
    for (final item in relTopics) {
      if (item is! Map<String, dynamic>) continue;
      final actId = (item['activity_id'] ?? '').toString();
      final topicId = (item['topic_id'] ?? '').toString();
      if (actId.isEmpty || topicId.isEmpty) continue;

      sugeridos.putIfAbsent(actId, () => []);
      if (!sugeridos[actId]!.contains(topicId)) {
        sugeridos[actId]!.add(topicId);
      }
    }

    // Asistentes
    final asistentesInst = parseItems(
      (json['attendeesInstitutional'] ?? <dynamic>[]) as List<dynamic>,
      fallback: Icons.apartment_rounded,
    );
    final asistentesLoc = parseItems(
      (json['attendeesLocal'] ?? <dynamic>[]) as List<dynamic>,
      fallback: Icons.groups_rounded,
    );

    // Resultados
    final resultados = parseItems(
      (json['results'] ?? <dynamic>[]) as List<dynamic>,
      fallback: Icons.check_circle_rounded,
    );

    return CatalogData(
      version: (json['version'] ?? 'unknown').toString(),
      actividades: actividades,
      subcategoriasByActividad: subcatsByAct,
      propositosBySubcat: purposesBySub,
      temas: temas,
      temasSugeridosIdsByActividad: sugeridos,
      asistentesInstitucionales: asistentesInst,
      asistentesLocales: asistentesLoc,
      resultados: resultados,
      matrizRiesgo: (json['matrizRiesgo'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Bajo', 'Medio', 'Alto', 'Prioritario'],
    );
  }
}

/// Items de catálogo personalizados agregados por el usuario
class CustomCatalogData {
  final List<CatItem> customActivities;
  final Map<String, List<CatItem>> customSubcategories;
  final Map<String, List<CatItem>> customPurposes;
  final List<CatItem> customTopics;
  final List<CatItem> customAttendeesInstitutional;
  final List<CatItem> customAttendeesLocal;

  CustomCatalogData({
    required this.customActivities,
    required this.customSubcategories,
    required this.customPurposes,
    required this.customTopics,
    required this.customAttendeesInstitutional,
    required this.customAttendeesLocal,
  });

  factory CustomCatalogData.empty() {
    return CustomCatalogData(
      customActivities: const <CatItem>[],
      customSubcategories: const <String, List<CatItem>>{},
      customPurposes: const <String, List<CatItem>>{},
      customTopics: const <CatItem>[],
      customAttendeesInstitutional: const <CatItem>[],
      customAttendeesLocal: const <CatItem>[],
    );
  }

  factory CustomCatalogData.fromJson(Map<String, dynamic> json) {
    List<CatItem> parseItems(List<dynamic> arr, IconData icon) {
      return arr.map((e) {
        final m = e as Map<String, dynamic>;
        return CatItem(
          id: (m['id'] ?? '').toString(),
          label: (m['name'] ?? m['label'] ?? '').toString(),
          icon: icon,
        );
      }).toList();
    }

    Map<String, List<CatItem>> parseItemsMap(Map<String, dynamic> map, IconData icon) {
      final result = <String, List<CatItem>>{};
      for (final entry in map.entries) {
        result[entry.key] = parseItems((entry.value as List?) ?? [], icon);
      }
      return result;
    }

    return CustomCatalogData(
      customActivities: parseItems(
        (json['customActivities'] ?? <dynamic>[]) as List<dynamic>,
        Icons.category_rounded,
      ),
      customSubcategories: parseItemsMap(
        (json['customSubcategories'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        Icons.subdirectory_arrow_right_rounded,
      ),
      customPurposes: parseItemsMap(
        (json['customPurposes'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        Icons.flag_rounded,
      ),
      customTopics: parseItems(
        (json['customTopics'] ?? <dynamic>[]) as List<dynamic>,
        Icons.local_offer_rounded,
      ),
      customAttendeesInstitutional: parseItems(
        (json['customAttendeesInstitutional'] ?? <dynamic>[]) as List<dynamic>,
        Icons.apartment_rounded,
      ),
      customAttendeesLocal: parseItems(
        (json['customAttendeesLocal'] ?? <dynamic>[]) as List<dynamic>,
        Icons.groups_rounded,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> itemsToJson(List<CatItem> items) {
      return items.map((item) => {'id': item.id, 'name': item.label}).toList();
    }

    Map<String, dynamic> itemsMapToJson(Map<String, List<CatItem>> map) {
      final result = <String, dynamic>{};
      for (final entry in map.entries) {
        result[entry.key] = itemsToJson(entry.value);
      }
      return result;
    }

    return {
      'customActivities': itemsToJson(customActivities),
      'customSubcategories': itemsMapToJson(customSubcategories),
      'customPurposes': itemsMapToJson(customPurposes),
      'customTopics': itemsToJson(customTopics),
      'customAttendeesInstitutional': itemsToJson(customAttendeesInstitutional),
      'customAttendeesLocal': itemsToJson(customAttendeesLocal),
    };
  }
}

/// Item de catálogo con id, label e ícono
class CatItem {
  /// Identificador único del ítem
  final String id;
  /// Etiqueta mostrada al usuario  
  final String label;
  /// Ícono asociado
  final IconData icon;
  
  /// Constructor del item de catálogo
  const CatItem({required this.id, required this.label, required this.icon});
  
  /// Alias para label (compatibilidad)
  String get name => label;
}

/// Estado de un candidato pendiente de aprobación
enum CandidateStatus {
  pending,   // Pendiente de revisión
  approved,  // Aprobado y agregado al catálogo
  rejected,  // Rechazado
}

/// Item candidato pendiente de aprobación del administrador
class CandidateItem {
  final String id;
  final String type; // 'activity', 'subcategory', 'purpose', 'topic', 'attendee_inst', 'attendee_local'
  final String name;
  final String? parentId; // ID del padre (ej. activityId para subcategoría)
  final String? reportId; // ID del reporte que originó el candidato
  final String? userId; // ID del usuario que lo propuso
  final DateTime proposedAt;
  CandidateStatus status;
  DateTime? reviewedAt;
  String? rejectionReason;

  CandidateItem({
    required this.id,
    required this.type,
    required this.name,
    this.parentId,
    this.reportId,
    this.userId,
    required this.proposedAt,
    required this.status,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory CandidateItem.fromJson(Map<String, dynamic> json) {
    return CandidateItem(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      parentId: json['parentId'] as String?,
      reportId: json['reportId'] as String?,
      userId: json['userId'] as String?,
      proposedAt: DateTime.parse(json['proposedAt'] as String),
      status: CandidateStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => CandidateStatus.pending,
      ),
      reviewedAt: json['reviewedAt'] != null 
          ? DateTime.parse(json['reviewedAt'] as String) 
          : null,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'parentId': parentId,
      'reportId': reportId,
      'userId': userId,
      'proposedAt': proposedAt.toIso8601String(),
      'status': status.name,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
    };
  }
}
