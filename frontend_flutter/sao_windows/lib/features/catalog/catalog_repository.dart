import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/api_client.dart';
import '../../data/local/app_db.dart';
import 'data/catalog_offline_repository.dart';
import 'models/catalog_bundle_models.dart';

class ProjectFrontOption {
  final String id;
  final String code;
  final String name;

  const ProjectFrontOption({
    required this.id,
    required this.code,
    required this.name,
  });
}

/// Catálogos DATA-DRIVEN.
/// Carga desde JSON base (assets/catalogos.json) + items personalizados (archivo local).
class CatalogRepository {
  CatalogRepository();

  String _projectId = 'TMQ';

  bool _ready = false;
  bool get isReady => _ready;

  CatalogData _data = CatalogData.fromJson({});
  CatalogData get data => _data;

  /// Devuelve el version_id del bundle activo (null si no hay bundle o no expone versión).
  String? get currentVersionId => _data.versionId;

  // Items personalizados agregados por el usuario
  CustomCatalogData _customData = CustomCatalogData.empty();

  // Items candidatos pendientes de aprobación del administrador
  List<CandidateItem> _pendingCandidates = [];

  /// Carga catálogo efectivo desde bundle (API) con fallback local.
  /// También carga items personalizados desde archivo local.
  Future<void> init({String projectId = 'TMQ', bool forceReload = false}) async {
    final normalized = projectId.trim().isEmpty ? 'TMQ' : projectId.trim().toUpperCase();
    final hasCatalogData = _data.actividades.isNotEmpty;
    if (!forceReload && _ready && _projectId == normalized && hasCatalogData) return;

    _projectId = normalized;

    await loadProjectBundle(_projectId);

    // Cargar items personalizados
    await _loadCustomData();
    await _loadPendingCandidates();

    _ready = true;
  }

  Future<void> loadProjectBundle(String projectId) async {
    _projectId = projectId.trim().isEmpty ? 'TMQ' : projectId.trim().toUpperCase();

    final cachedBundle = await _readCachedBundle(_projectId);
    if (cachedBundle != null) {
      final normalizedCached = _normalizeCatalogPayload(cachedBundle) ?? cachedBundle;
      _data = CatalogData.fromJson(normalizedCached);
      _ready = true;
      final cachedHasCatalog = _data.actividades.isNotEmpty;

      final localHash = _extractBundleHash(normalizedCached);
      final updateAvailable = await _checkUpdatesWithFallback(
        projectId: _projectId,
        localHash: localHash,
      );

      // Only trust cache as terminal state when it already contains usable catalog.
      if (cachedHasCatalog && updateAvailable == false) {
        return;
      }

      if (cachedHasCatalog && updateAvailable == null) {
        // Sin red o endpoint no disponible: conservar cache local.
        return;
      }
    }

    // 1. Try /catalog/bundle — canonical schema for wizard/admin.
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get<dynamic>(
        '/catalog/bundle',
        queryParameters: {'project_id': _projectId},
      );
      final map = _normalizeCatalogPayload(response.data);
      if (map == null) throw Exception('Invalid catalog payload from /catalog/bundle');
      final parsed = CatalogData.fromJson(map);
      if (parsed.actividades.isEmpty) {
        throw Exception('Empty catalog payload from /catalog/bundle');
      }
      await _saveCachedBundle(_projectId, map);
      _data = parsed;
      _ready = true;
      return;
    } catch (_) {}

    // 2. Try /api/v1/catalog/bundle for environments without API path prefixing.
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get<dynamic>(
        '/api/v1/catalog/bundle',
        queryParameters: {'project_id': _projectId},
      );
      final map = _normalizeCatalogPayload(response.data);
      if (map == null) throw Exception('Invalid catalog payload from /api/v1/catalog/bundle');
      final parsed = CatalogData.fromJson(map);
      if (parsed.actividades.isEmpty) {
        throw Exception('Empty catalog payload from /api/v1/catalog/bundle');
      }
      await _saveCachedBundle(_projectId, map);
      _data = parsed;
      _ready = true;
      return;
    } catch (_) {}

    // 3. Try /catalog/effective — fallback legacy endpoint.
    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get<dynamic>(
        '/catalog/effective',
        queryParameters: {'project_id': _projectId},
      );
      final map = _normalizeCatalogPayload(response.data);
      if (map == null) throw Exception('Invalid catalog payload from /catalog/effective');
      final parsed = CatalogData.fromJson(map);
      if (parsed.actividades.isEmpty) {
        throw Exception('Empty catalog payload from /catalog/effective');
      }
      await _saveCachedBundle(_projectId, map);
      _data = parsed;
      _ready = true;
      return;
    } catch (_) {}

    // 4. Keep cached bundle if available and network fetch failed.
    if (cachedBundle != null) {
      final normalizedCached = _normalizeCatalogPayload(cachedBundle) ?? cachedBundle;
      _data = CatalogData.fromJson(normalizedCached);
      _ready = true;
      return;
    }

    // 5. Last-resort fallback to bundled seed catalog so wizard dropdowns
    // never degrade to free-text only when remote catalog is unavailable.
    final seeded = await _loadBundledSeedCatalog();
    if (seeded != null && seeded.actividades.isNotEmpty) {
      _data = seeded;
      _ready = true;
      return;
    }

    // 6. Absolute fallback: keep empty model.
    _data = CatalogData.fromJson({});

    _ready = true;
  }

  /// Fuerza recarga remota del bundle (sin confiar en check-updates ni cache local).
  ///
  /// Se usa desde acciones manuales de "Actualizar catálogo" para evitar que
  /// el dispositivo conserve conceptos eliminados en servidor por un cache viejo.
  Future<void> refreshProjectBundleFromServer(
    String projectId, {
    bool purgeLocalCustom = false,
  }) async {
    _projectId = projectId.trim().isEmpty ? 'TMQ' : projectId.trim().toUpperCase();

    final endpoints = <String>[
      '/catalog/bundle',
      '/api/v1/catalog/bundle',
      '/catalog/effective',
    ];

    final apiClient = GetIt.instance<ApiClient>();
    for (final endpoint in endpoints) {
      try {
        final response = await apiClient.get<dynamic>(
          endpoint,
          queryParameters: {'project_id': _projectId},
        );
        final map = _normalizeCatalogPayload(response.data);
        if (map == null) {
          continue;
        }

        final parsed = CatalogData.fromJson(map);
        if (parsed.actividades.isEmpty) {
          continue;
        }

        await _saveCachedBundle(_projectId, map);
        _data = parsed;
        if (purgeLocalCustom) {
          _customData = CustomCatalogData.empty();
          _pendingCandidates = [];
          await _saveCustomData();
          await _savePendingCandidates();
        }
        _ready = true;
        return;
      } catch (_) {
        // Probar siguiente endpoint.
      }
    }

    // Fallback: mantener comportamiento anterior (cache/local seed) si red falla.
    await loadProjectBundle(_projectId);
  }

  Map<String, dynamic>? _normalizeCatalogPayload(dynamic payload) {
    if (payload is! Map) return null;

    final map = Map<String, dynamic>.from(payload.cast<dynamic, dynamic>());

    // Direct catalog payload signatures.
    if (map.containsKey('schema') ||
        map.containsKey('effective') ||
        map.containsKey('activities') ||
        map.containsKey('actividades')) {
      return map;
    }

    // Wrapped payload signatures often used by gateways/backends.
    const wrappers = <String>['data', 'bundle', 'catalog', 'result', 'payload'];
    for (final key in wrappers) {
      final nested = map[key];
      final normalized = _normalizeCatalogPayload(nested);
      if (normalized != null) return normalized;
    }

    return map;
  }

  Future<CatalogData?> _loadBundledSeedCatalog() async {
    const assetCandidates = <String>[
      'assets/base_seed_catalog.bundle.json',
      'assets/catalogos.json',
    ];

    for (final assetPath in assetCandidates) {
      try {
        final raw = await rootBundle.loadString(assetPath);
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final parsed = CatalogData.fromJson(decoded);
        if (parsed.actividades.isNotEmpty) {
          return parsed;
        }
      } catch (_) {
        // Try next asset candidate.
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> _readCachedBundle(String projectId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/catalog_bundle_${projectId.toUpperCase()}.json');
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedBundle(String projectId, Map<String, dynamic> bundle) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/catalog_bundle_${projectId.toUpperCase()}.json');
      await file.writeAsString(jsonEncode(bundle));
    } catch (_) {
      // Silently fail
    }
    // Also persist to Drift-backed store for versioned offline retention.
    await _persistOfflineBundle(projectId, bundle);
  }

  /// Persiste el bundle en las tablas Drift `catalog_index` y `catalog_bundles`.
  Future<void> _persistOfflineBundle(
    String projectId,
    Map<String, dynamic> bundle,
  ) async {
    try {
      final db = GetIt.instance<AppDb>();
      final offlineRepo = CatalogOfflineRepository(db: db);
      final meta = (bundle['meta'] as Map?)?.cast<String, dynamic>() ?? {};
      final versionId = meta['version_id']?.toString();
      final hash = meta['hash']?.toString() ?? meta['catalog_hash']?.toString();
      if (versionId == null || versionId.isEmpty) return;
      await offlineRepo.saveBundle(
        projectId: projectId,
        versionId: versionId,
        bundleJson: bundle,
      );
      await offlineRepo.upsertIndex(
        projectId: projectId,
        versionId: versionId,
        hash: hash,
      );
    } catch (_) {
      // Silently fail — Drift tables may not exist yet on first install.
    }
  }

  Future<bool?> _checkUpdatesWithFallback({
    required String projectId,
    String? localHash,
  }) async {
    final query = <String, dynamic>{'project_id': projectId};
    if (localHash != null && localHash.isNotEmpty) {
      query['current_hash'] = localHash;
    }

    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get<dynamic>(
        '/catalog/check-updates',
        queryParameters: query,
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return map['update_available'] == true;
    } catch (_) {}

    try {
      final apiClient = GetIt.instance<ApiClient>();
      final response = await apiClient.get<dynamic>(
        '/api/v1/catalog/check-updates',
        queryParameters: query,
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      return map['update_available'] == true;
    } catch (_) {}

    return null;
  }

  Future<List<ProjectFrontOption>> fetchFrontsForProject(String projectId) async {
    final normalized = projectId.trim().toUpperCase();
    if (normalized.isEmpty) return const [];

    final apiClient = GetIt.instance<ApiClient>();
    final endpoints = ['/fronts', '/api/v1/fronts'];

    for (final endpoint in endpoints) {
      try {
        final response = await apiClient.get<dynamic>(
          endpoint,
          queryParameters: {'project_id': normalized},
        );
        final rows = (response.data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return rows
            .map(
              (row) => ProjectFrontOption(
                id: (row['id'] ?? '').toString(),
                code: (row['code'] ?? '').toString(),
                name: (row['name'] ?? '').toString(),
              ),
            )
            .where((row) => row.id.trim().isNotEmpty && row.name.trim().isNotEmpty)
            .toList();
      } catch (_) {}
    }

    return const [];
  }

  Future<List<String>> fetchStatesForProject(String projectId) async {
    final normalized = projectId.trim().toUpperCase();
    if (normalized.isEmpty) return const [];

    final apiClient = GetIt.instance<ApiClient>();
    final endpoints = ['/locations/states', '/api/v1/locations/states'];

    for (final endpoint in endpoints) {
      try {
        final response = await apiClient.get<dynamic>(
          endpoint,
          queryParameters: {'project_id': normalized},
        );
        final rows = (response.data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return rows
            .map((row) => (row['estado'] ?? '').toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } catch (_) {}
    }

    return const [];
  }

  Future<List<String>> fetchMunicipiosForProject(String projectId, String estado) async {
    final normalizedProject = projectId.trim().toUpperCase();
    final normalizedState = estado.trim();
    if (normalizedProject.isEmpty || normalizedState.isEmpty) return const [];

    final apiClient = GetIt.instance<ApiClient>();
    final endpoints = ['/locations', '/api/v1/locations'];

    for (final endpoint in endpoints) {
      try {
        final response = await apiClient.get<dynamic>(
          endpoint,
          queryParameters: {
            'project_id': normalizedProject,
            'estado': normalizedState,
          },
        );
        final rows = (response.data as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        return rows
            .map((row) => (row['municipio'] ?? '').toString().trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      } catch (_) {}
    }

    return const [];
  }

  String? _extractBundleHash(Map<String, dynamic> bundle) {
    final direct = bundle['hash']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final meta = (bundle['meta'] as Map?)?.cast<String, dynamic>();
    if (meta == null) return null;

    final candidate =
        meta['hash'] ?? meta['catalog_hash'] ?? meta['bundle_hash'] ?? meta['checksum'];
    final normalized = candidate?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
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

  List<CatItem> purposesForCascade({
    required String activityId,
    String? subcategoryId,
  }) {
    final normalizedActivityId = activityId.trim();
    final normalizedSubcategoryId = subcategoryId?.trim();
    if (normalizedActivityId.isEmpty) return const [];

    final bySpecificSubcategory = (normalizedSubcategoryId == null || normalizedSubcategoryId.isEmpty)
        ? const <CatItem>[]
        : purposesFor(normalizedSubcategoryId, activityId: normalizedActivityId);

    final globals = _lookupMapList(_data.propositosBySubcat, '$normalizedActivityId|');
    final customGlobals = _lookupMapList(_customData.customPurposes, '$normalizedActivityId|');

    final merged = <String, CatItem>{
      for (final item in [...bySpecificSubcategory, ...globals, ...customGlobals]) item.id: item,
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

  String topicPolicyFor(String activityId) {
    final normalizedActivityId = activityId.trim();
    final rules = _data.rules;
    final topicPolicy = (rules['topic_policy'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final byActivity = (topicPolicy['by_activity'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final mode = byActivity[normalizedActivityId] ?? topicPolicy['default'] ?? 'any';
    return mode.toString().trim().isEmpty ? 'any' : mode.toString();
  }

  bool shouldAllowAllTopics(String activityId) {
    return topicPolicyFor(activityId) != 'suggested_only';
  }

  List<CatItem> topicsForActivity(String activityId) {
    final normalizedActivityId = activityId.trim();
    if (normalizedActivityId.isEmpty) return const [];
    if (!shouldAllowAllTopics(normalizedActivityId)) {
      return temasSugeridosFor(normalizedActivityId);
    }
    return temas;
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
  /// ID semántico de la versión del catálogo (ej: "tmq-v1"). Null si no hay bundle.
  final String? versionId;
  final List<CatItem> actividades;

  final Map<String, List<CatItem>> subcategoriasByActividad;
  final Map<String, List<CatItem>> propositosBySubcat;

  final List<CatItem> temas;
  final Map<String, List<String>> temasSugeridosIdsByActividad;

  final List<CatItem> asistentesInstitucionales;
  final List<CatItem> asistentesLocales;

  final List<CatItem> resultados;

  final List<String> matrizRiesgo;
  final Map<String, dynamic> rules;

  CatalogData({
    required this.version,
    this.versionId,
    required this.actividades,
    required this.subcategoriasByActividad,
    required this.propositosBySubcat,
    required this.temas,
    required this.temasSugeridosIdsByActividad,
    required this.asistentesInstitucionales,
    required this.asistentesLocales,
    required this.resultados,
    required this.matrizRiesgo,
    required this.rules,
  });

  factory CatalogData.fromJson(Map<String, dynamic> json) {
    if ((json['schema'] ?? '').toString() == 'sao.catalog.bundle.v1' || json['effective'] is Map<String, dynamic>) {
      return CatalogData.fromBundleJson(json);
    }

    bool parseRequiresGeo(Map<String, dynamic> row) {
      final value = row['requires_geo'] ?? row['requires_gps'];
      if (value is bool) return value;
      final normalized = value?.toString().toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    List<String> parseWorkflowChecklist(Map<String, dynamic> row) {
      final raw = row['workflow_checklist'];
      if (raw is List) {
        return raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    List<CatItem> parseItems(
      List<dynamic> arr, {
      IconData fallback = Icons.list_alt_rounded,
      bool includeRequiresGeo = false,
    }) {
      return arr.map((e) {
        final m = e as Map<String, dynamic>;
        return CatItem(
          id: (m['id'] ?? m['activity_id'] ?? m['subcategory_id'] ?? m['topic_id'] ?? '').toString(),
          label: (m['name_effective'] ?? m['name'] ?? m['nombre'] ?? m['label'] ?? '').toString(),
          icon: fallback,
          requiresGeo: includeRequiresGeo ? parseRequiresGeo(m) : false,
          workflowChecklist: includeRequiresGeo ? parseWorkflowChecklist(m) : const <String>[],
        );
      }).toList();
    }

    // Activities
    final actividades = parseItems(
      (json['activities'] ?? <dynamic>[]) as List<dynamic>,
      fallback: Icons.category_rounded,
      includeRequiresGeo: true,
    );

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
      rules: const <String, dynamic>{},
    );
  }

  factory CatalogData.fromBundleJson(Map<String, dynamic> json) {
    final bundle = CatalogBundle.fromJson(json);
    final entities = bundle.effective.entities;

    bool parseRequiresGeo(Map<String, dynamic> row) {
      final value = row['requires_geo'] ?? row['requires_gps'];
      if (value is bool) return value;
      final normalized = value?.toString().toLowerCase().trim();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    List<String> parseWorkflowChecklist(Map<String, dynamic> row) {
      final raw = row['workflow_checklist'];
      if (raw is List) {
        return raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    List<CatItem> toCatItems(
      List<Map<String, dynamic>> rows, {
      required IconData fallback,
      bool includeRequiresGeo = false,
    }) {
      return rows
          .where((row) => (row['active'] as bool?) ?? true)
          .map((row) {
            final name = (row['name_effective'] ?? row['name'] ?? row['label'] ?? '').toString();
            final id = (row['id'] ?? '').toString();
            return CatItem(
              id: id,
              label: name,
              icon: fallback,
              requiresGeo: includeRequiresGeo ? parseRequiresGeo(row) : false,
              workflowChecklist: includeRequiresGeo ? parseWorkflowChecklist(row) : const <String>[],
            );
          })
          .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
          .toList();
    }

    final actividades = toCatItems(
      entities.activities,
      fallback: Icons.category_rounded,
      includeRequiresGeo: true,
    );

    final subcatsByAct = <String, List<CatItem>>{};
    for (final row in entities.subcategories.where((row) => (row['active'] as bool?) ?? true)) {
      final activityId = (row['activity_id'] ?? '').toString();
      final subcatId = (row['id'] ?? '').toString();
      final name = (row['name_effective'] ?? row['name'] ?? row['label'] ?? '').toString();
      if (activityId.isEmpty || subcatId.isEmpty || name.isEmpty) continue;

      final item = CatItem(
        id: subcatId,
        label: name,
        icon: Icons.subdirectory_arrow_right_rounded,
      );
      subcatsByAct.putIfAbsent(activityId, () => []);
      if (!subcatsByAct[activityId]!.any((x) => x.id == item.id)) {
        subcatsByAct[activityId]!.add(item);
      }
    }

    final purposesBySub = <String, List<CatItem>>{};
    for (final row in entities.purposes.where((row) => (row['active'] as bool?) ?? true)) {
      final purposeId = (row['id'] ?? '').toString();
      final activityId = (row['activity_id'] ?? '').toString();
      final subcategoryRaw = row.containsKey('subcategory_id') ? row['subcategory_id'] : null;
      final subcategoryId = subcategoryRaw?.toString();
      final name = (row['name_effective'] ?? row['name'] ?? row['label'] ?? '').toString();
      if (purposeId.isEmpty || name.isEmpty) continue;

      final purposeItem = CatItem(
        id: purposeId,
        label: name,
        icon: Icons.flag_rounded,
      );

      if (subcategoryId != null && subcategoryId.isNotEmpty) {
        purposesBySub.putIfAbsent(subcategoryId, () => []);
        if (!purposesBySub[subcategoryId]!.any((x) => x.id == purposeItem.id)) {
          purposesBySub[subcategoryId]!.add(purposeItem);
        }
      }

      if (activityId.isNotEmpty) {
        final composite = '$activityId|${subcategoryId ?? ''}';
        purposesBySub.putIfAbsent(composite, () => []);
        if (!purposesBySub[composite]!.any((x) => x.id == purposeItem.id)) {
          purposesBySub[composite]!.add(purposeItem);
        }

        if (subcategoryId == null || subcategoryId.isEmpty) {
          final activityOnly = '$activityId|';
          purposesBySub.putIfAbsent(activityOnly, () => []);
          if (!purposesBySub[activityOnly]!.any((x) => x.id == purposeItem.id)) {
            purposesBySub[activityOnly]!.add(purposeItem);
          }
        }
      }
    }

    final temas = toCatItems(
      entities.topics,
      fallback: Icons.local_offer_rounded,
    );

    final sugeridos = <String, List<String>>{};
    for (final row in bundle.effective.relations.activityToTopicsSuggested
        .where((row) => (row['active'] as bool?) ?? true)) {
      final activityId = (row['activity_id'] ?? '').toString();
      final topicId = (row['topic_id'] ?? '').toString();
      if (activityId.isEmpty || topicId.isEmpty) continue;
      sugeridos.putIfAbsent(activityId, () => []);
      if (!sugeridos[activityId]!.contains(topicId)) {
        sugeridos[activityId]!.add(topicId);
      }
    }

    final resultados = toCatItems(
      entities.results,
      fallback: Icons.check_circle_rounded,
    );

    final assistants = entities.assistants.where((row) => (row['active'] as bool?) ?? true).toList();
    final assistantsInstRows = assistants.where((row) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      return type.contains('dependencia') || type.contains('instit');
    }).toList();
    final assistantsLocalRows = assistants.where((row) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      return !(type.contains('dependencia') || type.contains('instit'));
    }).toList();

    final asistentesInst = toCatItems(assistantsInstRows, fallback: Icons.apartment_rounded);
    final asistentesLoc = toCatItems(assistantsLocalRows, fallback: Icons.groups_rounded);

    return CatalogData(
      version: (bundle.meta['bundle_id'] ?? bundle.meta['project_id'] ?? 'bundle').toString(),
      versionId: bundle.meta['version_id']?.toString(),
      actividades: actividades,
      subcategoriasByActividad: subcatsByAct,
      propositosBySubcat: purposesBySub,
      temas: temas,
      temasSugeridosIdsByActividad: sugeridos,
      asistentesInstitucionales: asistentesInst,
      asistentesLocales: asistentesLoc,
      resultados: resultados,
      matrizRiesgo: const ['Bajo', 'Medio', 'Alto', 'Prioritario'],
      rules: bundle.effective.rules,
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
      customActivities: <CatItem>[],
      customSubcategories: <String, List<CatItem>>{},
      customPurposes: <String, List<CatItem>>{},
      customTopics: <CatItem>[],
      customAttendeesInstitutional: <CatItem>[],
      customAttendeesLocal: <CatItem>[],
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
  /// Requiere captura GPS (lat/lon) para guardar
  final bool requiresGeo;
  /// Checklist de workflow de la actividad (ej: photo_min_1, gps_point)
  final List<String> workflowChecklist;
  
  /// Constructor del item de catálogo
  const CatItem({
    required this.id,
    required this.label,
    required this.icon,
    this.requiresGeo = false,
    this.workflowChecklist = const <String>[],
  });

  int get minimumEvidencePhotos {
    final matcher = RegExp(r'^photo_min_(\d+)$');
    var required = 0;
    for (final token in workflowChecklist) {
      final match = matcher.firstMatch(token.trim().toLowerCase());
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value == null) continue;
      if (value > required) required = value;
    }
    return required;
  }
  
  /// Alias para label (compatibilidad)
  String get name => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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
