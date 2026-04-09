import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/data_mode.dart';
import 'backend_api_client.dart';
import 'catalog_bundle_models.dart';

class CatalogRepository {
  CatalogRepository();

  final Random _opRandom = Random();

  final BackendApiClient _apiClient = const BackendApiClient();

  bool _ready = false;
  bool get isReady => _ready;

  String _projectId = '';
  String get projectId => _projectId;

  CatalogBundle? _lastBundle;
  CatalogBundle? get lastBundle => _lastBundle;

  String? get lastCatalogVersionId {
    final meta = _lastBundle?.meta ?? const <String, dynamic>{};
    final versions = (meta['versions'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final version = (versions['effective'] ?? meta['version_id'])?.toString();
    if (version == null || version.trim().isEmpty) {
      return null;
    }
    return version.trim();
  }

  String get lastCatalogStatus {
    final meta = _lastBundle?.meta ?? const <String, dynamic>{};
    final versions = (meta['versions'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final status = (versions['status'] ?? '').toString().trim().toLowerCase();
    if (status.isEmpty) {
      return 'unknown';
    }
    return status;
  }

  bool get hasPendingProjectOps {
    final editor = _lastBundle?.editor;
    if (editor == null) {
      return false;
    }
    final layers = editor.layers;
    final projectLayer = (layers['project'] as Map?)?.cast<String, dynamic>();
    final ops = (projectLayer?['ops'] as List?) ?? const [];
    return ops.isNotEmpty;
  }

  CatalogData _data = CatalogData.empty();
  CatalogData get data => _data;

  String? _lastEditorVersionId;
  String? get lastEditorVersionId => _lastEditorVersionId;

  Set<String> _activityAliases(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const <String>{};

    final aliases = <String>{
      value,
      value.toUpperCase(),
      value.toLowerCase(),
    };

    final upper = value.toUpperCase();
    if (upper.startsWith('ACT-TYPE-') && value.length > 9) {
      final stripped = value.substring(9).trim();
      if (stripped.isNotEmpty) {
        aliases
          ..add(stripped)
          ..add(stripped.toUpperCase())
          ..add(stripped.toLowerCase());
      }
    }
    return aliases;
  }

  bool _sameActivityId(String left, String right) {
    final leftAliases = _activityAliases(left);
    if (leftAliases.isEmpty) return false;
    final rightAliases = _activityAliases(right);
    if (rightAliases.isEmpty) return false;
    return leftAliases.any(rightAliases.contains);
  }

  Future<void> init({String projectId = ''}) async {
    await loadProject(projectId);
  }

  Future<void> loadProject(String projectId) async {
    _projectId = projectId.trim().toUpperCase();

    if (AppDataMode.backendBaseUrl.trim().isEmpty) {
      await _loadFromBundleAsset();
      _ready = true;
      return;
    }

    final encoded = Uri.encodeQueryComponent(_projectId);

    // 1. Try /catalog/bundle — canonical endpoint for admin + wizard.
    try {
      final bundle = await getBundle(_projectId, includeEditor: true);
      if (bundle != null) {
        _lastBundle = bundle;
        _data = CatalogData.fromBundle(bundle);
        _ready = true;
        print('[CATALOG] Loaded from /catalog/bundle for project=$_projectId, version=${lastCatalogVersionId ?? "unknown"}');
        return;
      }
    } catch (_) {}

    // 2. Try /catalog/effective — fallback schema used by current backend.
    try {
      final decoded = await _apiClient
          .getJson('/api/v1/catalog/effective?project_id=$encoded');
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('activities')) {
        _data = CatalogData.fromEffectiveJson(decoded);
        _ready = true;
        print('[CATALOG] Loaded from /catalog/effective for project=$_projectId');
        return;
      }
    } catch (_) {}

    // 3. Try /catalog/editor — fallback for admin editor view.
    try {
      final decoded = await _apiClient
          .getJson('/api/v1/catalog/editor?project_id=$encoded');
      if (decoded is Map<String, dynamic>) {
        _data = CatalogData.fromEditorJson(decoded);
        _lastEditorVersionId = _extractVersionIdFromEditor(decoded);
        _ready = true;
        print('[CATALOG] Loaded from /catalog/editor for project=$_projectId, version=$_lastEditorVersionId');
        return;
      }
    } catch (_) {}

    // 4. All API attempts failed — use bundled asset as last resort.
    await _loadFromBundleAsset();
    _ready = true;
  }

  Future<CatalogBundle?> getBundle(String projectId,
      {bool includeEditor = false}) async {
    final normalized =
        projectId.trim().isEmpty ? _projectId : projectId.trim().toUpperCase();
    final encoded = Uri.encodeQueryComponent(normalized);
    final includeEditorFlag = includeEditor ? '&include_editor=true' : '';
    final decoded = await _apiClient.getJson(
      '/api/v1/catalog/bundle?project_id=$encoded$includeEditorFlag',
    );
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return CatalogBundle.fromJson(decoded);
  }

  Future<void> _loadFromBundleAsset() async {
    try {
      final raw =
          await rootBundle.loadString('assets/base_seed_catalog.bundle.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final bundle = CatalogBundle.fromJson(decoded);
      _lastBundle = bundle;
      _data = CatalogData.fromBundle(bundle);
    } catch (_) {
      _data = CatalogData.empty();
    }
  }

  Future<void> createActivity({
    required String id,
    required String name,
    String? description,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'activities',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'name': name.trim(),
            'description': description,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updateActivity(
    String id, {
    String? name,
    String? description,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'activities',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteActivity(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'activities', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> createSubcategory({
    required String id,
    required String activityId,
    required String name,
    String? description,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'subcategories',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'activity_id': activityId.trim(),
            'name': name.trim(),
            'description': description,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updateSubcategory(
    String id, {
    String? activityId,
    String? name,
    String? description,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (activityId != null) payload['activity_id'] = activityId.trim();
    if (name != null) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'subcategories',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteSubcategory(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'subcategories', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> createPurpose({
    required String id,
    required String activityId,
    String? subcategoryId,
    required String name,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'purposes',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'activity_id': activityId.trim(),
            'subcategory_id': subcategoryId,
            'name': name.trim(),
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updatePurpose(
    String id, {
    String? activityId,
    String? subcategoryId,
    String? name,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (activityId != null) payload['activity_id'] = activityId.trim();
    if (subcategoryId != null) payload['subcategory_id'] = subcategoryId.trim();
    if (name != null) payload['name'] = name.trim();
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'purposes',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deletePurpose(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'purposes', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> createTopic({
    required String id,
    required String name,
    String? type,
    String? description,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'topics',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'name': name.trim(),
            'type': type,
            'description': description,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updateTopic(
    String id, {
    String? name,
    String? type,
    String? description,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (type != null) payload['type'] = type;
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'topics',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteTopic(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'topics', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> createResult({
    required String id,
    required String category,
    required String name,
    String? description,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'results',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'category': category.trim(),
            'name': name.trim(),
            'description': description,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updateResult(
    String id, {
    String? category,
    String? name,
    String? description,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (category != null) payload['category'] = category.trim();
    if (name != null) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'results',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteResult(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'results', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> createAssistant({
    required String id,
    required String type,
    required String name,
    String? description,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'assistants',
          'id': id.trim(),
          'payload': {
            'id': id.trim(),
            'type': type.trim(),
            'name': name.trim(),
            'description': description,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> updateAssistant(
    String id, {
    String? type,
    String? name,
    String? description,
    bool? isActive,
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final payload = <String, dynamic>{};
    if (type != null) payload['type'] = type.trim();
    if (name != null) payload['name'] = name.trim();
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['active'] = isActive;
    await _patchProjectOps(
      [
        {
          'op': 'patch',
          'entity': 'assistants',
          'id': id,
          'payload': payload,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteAssistant(String id, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [{'op': 'delete', 'entity': 'assistants', 'id': id}],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> addRelation(String activityId, String topicId, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'upsert',
          'entity': 'activity_to_topics_suggested',
          'id': '$activityId|$topicId',
          'payload': {
            'activity_id': activityId,
            'topic_id': topicId,
            'active': true,
          },
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> deleteRelation(String activityId, String topicId, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'delete',
          'entity': 'activity_to_topics_suggested',
          'id': '$activityId|$topicId',
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> reorder(String entity, List<String> ids, {String? projectId}) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    await _patchProjectOps(
      [
        {
          'op': 'reorder',
          'entity': entity,
          'ids': ids,
        }
      ],
      projectId: normalizedProjectId,
    );
    await loadProject(normalizedProjectId);
  }

  Future<void> _patchProjectOps(
    List<Map<String, dynamic>> ops, {
    String? reason,
    String? ticket,
    String actor = 'desktop-admin',
    String? projectId,
  }) async {
    final normalizedProjectId = (projectId ?? _projectId).trim().toUpperCase();
    final queryProject = Uri.encodeQueryComponent(normalizedProjectId);
    final now = DateTime.now().toUtc().toIso8601String();
    final enrichedOps = ops.map((op) {
      final opId =
          'op_${DateTime.now().millisecondsSinceEpoch}_${_opRandom.nextInt(1 << 20)}';
      final withDefaults = <String, dynamic>{
        ...op,
        'op_id': opId,
        'scope': {'project_id': normalizedProjectId},
        'meta': {
          'who': actor,
          'when': now,
          'reason': reason ?? 'catalog_editor_mutation',
          'ticket': ticket,
        },
      };
      return withDefaults;
    }).toList();

    final summary = enrichedOps
        .map((o) => '${o['op']}:${o['entity']}:${o['id']}')
        .join(', ');
    // ignore: avoid_print
    print(
        '[catalog_ops] PATCH /project-ops project=$normalizedProjectId ops=[$summary]');

    try {
      await _apiClient
          .patchJson('/api/v1/catalog/project-ops?project_id=$queryProject', {
        'ops': enrichedOps,
      });
      // ignore: avoid_print
      print('[catalog_ops] project-ops OK');
      return;
    } catch (e) {
      // ignore: avoid_print
      print('[catalog_ops] project-ops FAILED: $e — trying bundle path');
      try {
        await _apiClient.patchJson(
            '/api/v1/catalog/bundle/project-ops?project_id=$queryProject', {
          'ops': enrichedOps,
        });
        // ignore: avoid_print
        print('[catalog_ops] bundle/project-ops OK');
        return;
      } catch (e2) {
        // ignore: avoid_print
        print(
            '[catalog_ops] bundle/project-ops FAILED: $e2 — falling back to editor CRUD');
        await _applyEditorOpsFallback(ops);
      }
    }
  }

  Future<CatalogAdminHookResult> validateDraftCatalog() async {
    final queryProject = Uri.encodeQueryComponent(_projectId);
    try {
      await _apiClient
          .postJson('/api/v1/catalog/validate?project_id=$queryProject', {});
      return const CatalogAdminHookResult(
        supported: true,
        success: true,
        message: 'Validación bundle completada.',
      );
    } catch (_) {
      try {
        await _apiClient.postJson(
            '/api/v1/catalog/bundle/validate?project_id=$queryProject', {});
        return const CatalogAdminHookResult(
          supported: true,
          success: true,
          message: 'Validación bundle completada.',
        );
      } catch (_) {}
      try {
        final decoded = await _apiClient
            .getJson('/api/v1/catalog/editor?project_id=$queryProject');
        final versionId = decoded is Map<String, dynamic>
            ? _extractVersionIdFromEditor(decoded)
            : null;
        return CatalogAdminHookResult(
          supported: false,
          success: true,
          message:
              'Backend sin /bundle/validate; validación base en /catalog/editor completada.',
          versionId: versionId,
        );
      } catch (error) {
        return CatalogAdminHookResult(
          supported: false,
          success: false,
          message: 'No fue posible validar catálogo: $error',
        );
      }
    }
  }

  Future<CatalogAdminHookResult> publishDraftCatalog({String? notes}) async {
    final queryProject = Uri.encodeQueryComponent(_projectId);
    try {
      final payload = <String, dynamic>{};
      final normalizedNotes = notes?.trim();
      if (normalizedNotes != null && normalizedNotes.isNotEmpty) {
        payload['notes'] = normalizedNotes;
      }
      await _apiClient.postJson(
          '/api/v1/catalog/publish?project_id=$queryProject', payload);
      await loadProject(_projectId);
      return const CatalogAdminHookResult(
        supported: true,
        success: true,
        message: 'Publicación bundle completada.',
      );
    } catch (_) {
      try {
        final payload = <String, dynamic>{};
        final normalizedNotes = notes?.trim();
        if (normalizedNotes != null && normalizedNotes.isNotEmpty) {
          payload['notes'] = normalizedNotes;
        }
        await _apiClient.postJson(
            '/api/v1/catalog/bundle/publish?project_id=$queryProject', payload);
        await loadProject(_projectId);
        return const CatalogAdminHookResult(
          supported: true,
          success: true,
          message: 'Publicación bundle completada.',
        );
      } catch (_) {}
      final draftVersionId = await _resolveDraftVersionId();
      if (draftVersionId == null) {
        return const CatalogAdminHookResult(
          supported: false,
          success: false,
          message: 'No existe versión DRAFT para publicar en backend actual.',
        );
      }

      final payload = <String, dynamic>{};
      final normalizedNotes = notes?.trim();
      if (normalizedNotes != null && normalizedNotes.isNotEmpty) {
        payload['notes'] = normalizedNotes;
      }

      try {
        await _apiClient.postJson(
            '/api/v1/catalog/versions/$draftVersionId/publish', payload);
        await loadProject(_projectId);
        return CatalogAdminHookResult(
          supported: false,
          success: true,
          message:
              'Publicación completada usando /catalog/versions/{id}/publish.',
          versionId: draftVersionId,
        );
      } catch (error) {
        return CatalogAdminHookResult(
          supported: false,
          success: false,
          message: 'No fue posible publicar catálogo: $error',
          versionId: draftVersionId,
        );
      }
    }
  }

  Future<CatalogAdminHookResult> rollbackDraftCatalog() async {
    final queryProject = Uri.encodeQueryComponent(_projectId);
    try {
      await _apiClient
          .postJson('/api/v1/catalog/rollback?project_id=$queryProject', {});
      await loadProject(_projectId);
      return const CatalogAdminHookResult(
        supported: true,
        success: true,
        message: 'Rollback bundle completado.',
      );
    } catch (_) {
      try {
        await _apiClient.postJson(
            '/api/v1/catalog/bundle/rollback?project_id=$queryProject', {});
        await loadProject(_projectId);
        return const CatalogAdminHookResult(
          supported: true,
          success: true,
          message: 'Rollback bundle completado.',
        );
      } catch (_) {}
      return const CatalogAdminHookResult(
        supported: false,
        success: false,
        message:
            'El backend actual no expone endpoint de rollback de catálogo.',
      );
    }
  }

  Future<void> _applyEditorOpsFallback(List<Map<String, dynamic>> ops) async {
    for (final op in ops) {
      final entity = (op['entity'] ?? '').toString();
      final operation = (op['op'] ?? '').toString();
      final id = op['id']?.toString();
      final payload = (op['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      switch (entity) {
        case 'activities':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/activities',
            updatePath:
                id != null ? '/api/v1/catalog/editor/activities/$id' : null,
            deletePath:
                id != null ? '/api/v1/catalog/editor/activities/$id' : null,
            payload: payload,
          );
          break;
        case 'subcategories':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/subcategories',
            updatePath:
                id != null ? '/api/v1/catalog/editor/subcategories/$id' : null,
            deletePath:
                id != null ? '/api/v1/catalog/editor/subcategories/$id' : null,
            payload: payload,
          );
          break;
        case 'purposes':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/purposes',
            updatePath:
                id != null ? '/api/v1/catalog/editor/purposes/$id' : null,
            deletePath:
                id != null ? '/api/v1/catalog/editor/purposes/$id' : null,
            payload: payload,
          );
          break;
        case 'topics':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/topics',
            updatePath: id != null ? '/api/v1/catalog/editor/topics/$id' : null,
            deletePath: id != null ? '/api/v1/catalog/editor/topics/$id' : null,
            payload: payload,
          );
          break;
        case 'results':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/results',
            updatePath:
                id != null ? '/api/v1/catalog/editor/results/$id' : null,
            deletePath:
                id != null ? '/api/v1/catalog/editor/results/$id' : null,
            payload: payload,
          );
          break;
        case 'assistants':
          await _applyEntityOpFallback(
            operation: operation,
            createPath: '/api/v1/catalog/editor/attendees',
            updatePath:
                id != null ? '/api/v1/catalog/editor/attendees/$id' : null,
            deletePath:
                id != null ? '/api/v1/catalog/editor/attendees/$id' : null,
            payload: payload,
          );
          break;
        case 'activity_to_topics_suggested':
          if (operation == 'upsert') {
            await _apiClient.postJson(
                _withProjectQuery('/api/v1/catalog/editor/rel-activity-topics'),
                {
                  'activity_id': payload['activity_id'],
                  'topic_id': payload['topic_id'],
                });
          } else if (operation == 'delete') {
            final parts = (id ?? '').split('|');
            if (parts.length == 2) {
              final activity = Uri.encodeQueryComponent(parts[0]);
              final topic = Uri.encodeQueryComponent(parts[1]);
              await _requestNoBody(
                'DELETE',
                _withProjectQuery(
                    '/api/v1/catalog/editor/rel-activity-topics?activity_id=$activity&topic_id=$topic'),
              );
            }
          }
          break;
        case 'activity':
        case 'subcategory':
        case 'purpose':
        case 'topic':
          if (operation == 'reorder') {
            final ids = (op['ids'] as List?)
                    ?.map((entry) => entry.toString())
                    .toList() ??
                const <String>[];
            await _apiClient.postJson(
              '/api/v1/catalog/editor/reorder?project_id=${Uri.encodeQueryComponent(_projectId)}',
              {
                'entity': entity,
                'ids': ids,
              },
            );
          }
          break;
        default:
          break;
      }
    }
  }

  Future<void> _applyEntityOpFallback({
    required String operation,
    required String createPath,
    required String? updatePath,
    required String? deletePath,
    required Map<String, dynamic> payload,
  }) async {
    if (operation == 'upsert') {
      final createPayload = Map<String, dynamic>.from(payload)
        ..remove('active');
      await _apiClient.postJson(_withProjectQuery(createPath), createPayload);

      final active = payload['active'];
      if (active is bool && !active && updatePath != null) {
        await _apiClient
            .patchJson(_withProjectQuery(updatePath), {'is_active': false});
      }
      return;
    }

    if (operation == 'patch' && updatePath != null) {
      final updatePayload = Map<String, dynamic>.from(payload);
      if (updatePayload.containsKey('active')) {
        updatePayload['is_active'] = updatePayload.remove('active');
      }
      await _apiClient.patchJson(_withProjectQuery(updatePath), updatePayload);
      return;
    }

    if (operation == 'delete' && deletePath != null) {
      await _requestNoBody('DELETE', _withProjectQuery(deletePath));
    }
  }

  Future<String?> _resolveDraftVersionId() async {
    final queryProject = Uri.encodeQueryComponent(_projectId);
    final decoded = await _apiClient.getJson(
        '/api/v1/catalog/versions?project_id=$queryProject&status=DRAFT&limit=1');
    if (decoded is! List || decoded.isEmpty) {
      return null;
    }
    final first = decoded.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }
    return first['id']?.toString();
  }

  String? _extractVersionIdFromEditor(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map<String, dynamic>) {
      return null;
    }
    final versionId = meta['version_id'];
    if (versionId is String && versionId.trim().isNotEmpty) {
      return versionId;
    }
    return null;
  }

  List<CatItem> getActivityTypes() {
    return _data.activities
        .where((activity) => activity.isActive)
        .map((activity) => CatItem(id: activity.id, name: activity.name))
        .toList();
  }

  List<CatItem> subcategoriesFor(String activityId) {
    final normalized = activityId.trim();
    if (normalized.isEmpty) return const <CatItem>[];
    return _data.subcategories
        .where((entry) =>
            entry.isActive && _sameActivityId(entry.activityId, normalized))
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<CatItem> purposesFor({
    required String activityId,
    String? subcategoryId,
  }) {
    final normalizedActivity = activityId.trim();
    final normalizedSubcategory = subcategoryId?.trim();
    if (normalizedActivity.isEmpty) return const <CatItem>[];

    return _data.purposes
        .where((entry) {
          if (!entry.isActive) return false;
          if (!_sameActivityId(entry.activityId, normalizedActivity)) {
            return false;
          }
          if (normalizedSubcategory == null || normalizedSubcategory.isEmpty) {
            // In review flows we need the full purpose space for the activity,
            // not only global purposes.
            return true;
          }
          final isGlobal = entry.subcategoryId == null ||
              entry.subcategoryId!.trim().isEmpty;
          return isGlobal || entry.subcategoryId == normalizedSubcategory;
        })
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<CatItem> temasSugeridosFor(String activityId,
      {bool includeAllWhenAllowed = true}) {
    final normalized = activityId.trim();
    if (normalized.isEmpty) return const <CatItem>[];

    final activeTopics = _data.topics.where((entry) => entry.isActive).toList();
    final mapById = {for (final topic in activeTopics) topic.id: topic};

    final suggestedIds = _data.relations
      .where((entry) =>
        entry.isActive && _sameActivityId(entry.activityId, normalized))
        .map((entry) => entry.topicId)
        .toSet();

    final mode =
        _lastBundle?.effective.rules.topicPolicy.modeFor(normalized) ?? 'any';
    final suggested = [
      for (final id in suggestedIds)
        if (mapById[id] != null) mapById[id]!
    ].map((entry) => CatItem(id: entry.id, name: entry.name)).toList();

    // Always return only suggested topics for project scope (no global fallback)
    return suggested;
  }

  List<CatItem> getResults() {
    return _data.results
        .where((entry) => entry.isActive)
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<CatItem> getAssistants() {
    return _data.assistants
        .where((entry) => entry.isActive)
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<String> getMunicipalities() {
    final dynamicValues = _extractLocationValuesFromBundle(
      municipalityKeys: const ['municipio', 'municipality'],
      stateKeys: const ['estado', 'state'],
      wantMunicipalities: true,
    );
    // Return only data from loaded bundle, not global fallback
    return dynamicValues;
  }

  List<String> getStates() {
    final dynamicValues = _extractLocationValuesFromBundle(
      municipalityKeys: const ['municipio', 'municipality'],
      stateKeys: const ['estado', 'state'],
      wantMunicipalities: false,
    );
    // Return only data from loaded bundle, not global fallback
    return dynamicValues;
  }

  List<String> _extractLocationValuesFromBundle({
    required List<String> municipalityKeys,
    required List<String> stateKeys,
    required bool wantMunicipalities,
  }) {
    final valuesByKey = <String, String>{};

    void addValue(String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) return;
      valuesByKey.putIfAbsent(value.toLowerCase(), () => value);
    }

    void visit(dynamic node) {
      if (node is Map) {
        final map = node.cast<dynamic, dynamic>();

        String? pickValue(List<String> keys) {
          for (final key in keys) {
            if (map.containsKey(key)) {
              return map[key]?.toString();
            }
          }
          return null;
        }

        final municipality = pickValue(municipalityKeys);
        final state = pickValue(stateKeys);
        if (wantMunicipalities) {
          addValue(municipality);
        } else {
          addValue(state);
        }

        for (final value in map.values) {
          visit(value);
        }
        return;
      }

      if (node is List) {
        for (final item in node) {
          visit(item);
        }
      }
    }

    final bundle = _lastBundle;
    if (bundle != null) {
      visit(bundle.meta);
      visit(bundle.editor.layers);
      visit(bundle.effective.formFields);
      visit(bundle.effective.rules.workflowJson);
    }

    final values = valuesByKey.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  Future<void> _requestNoBody(String method, String path) async {
    switch (method) {
      case 'DELETE':
        await _apiClient.deleteJson(path);
        break;
      default:
        throw StateError('Unsupported method: $method');
    }
  }

  String _withProjectQuery(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return '$path${separator}project_id=${Uri.encodeQueryComponent(_projectId)}';
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

class CatalogData {
  final List<CatalogActivityItem> activities;
  final List<CatalogSubcategoryItem> subcategories;
  final List<CatalogPurposeItem> purposes;
  final List<CatalogTopicItem> topics;
  final List<CatalogResultItem> results;
  final List<CatalogAssistantItem> assistants;
  final List<CatalogRelationItem> relations;

  CatalogData({
    required this.activities,
    required this.subcategories,
    required this.purposes,
    required this.topics,
    required this.results,
    required this.assistants,
    required this.relations,
  });

  static Set<String> _activityIdAliases(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const <String>{};

    final aliases = <String>{
      value,
      value.toUpperCase(),
      value.toLowerCase(),
    };

    final upper = value.toUpperCase();
    if (upper.startsWith('ACT-TYPE-') && value.length > 9) {
      final stripped = value.substring(9).trim();
      if (stripped.isNotEmpty) {
        aliases
          ..add(stripped)
          ..add(stripped.toUpperCase())
          ..add(stripped.toLowerCase());
      }
    }

    return aliases;
  }

  static bool _matchesKnownActivityId(String candidate, Set<String> knownAliases) {
    final value = candidate.trim();
    if (value.isEmpty) return false;
    for (final alias in _activityIdAliases(value)) {
      if (knownAliases.contains(alias)) return true;
    }
    return false;
  }

  Map<String, List<CatItem>> get subcategoriesByActivity {
    final result = <String, List<CatItem>>{};
    for (final item in subcategories.where((item) => item.isActive)) {
      result.putIfAbsent(item.activityId, () => <CatItem>[]);
      result[item.activityId]!.add(CatItem(id: item.id, name: item.name));
    }
    return result;
  }

  Map<String, List<CatItem>> get purposesBySubcategory {
    final result = <String, List<CatItem>>{};
    for (final item in purposes
        .where((item) => item.isActive && item.subcategoryId != null)) {
      result.putIfAbsent(item.subcategoryId!, () => <CatItem>[]);
      result[item.subcategoryId!]!.add(CatItem(id: item.id, name: item.name));
    }
    return result;
  }

  /// Parses the /catalog/effective response (production schema).
  /// Fields use _effective suffix: name_effective, is_enabled_effective, sort_order_effective.
  factory CatalogData.fromEffectiveJson(Map<String, dynamic> json) {
    bool asBool(dynamic value, {bool fallback = true}) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return fallback;
    }

    String strName(Map<String, dynamic> r) =>
        (r['name_effective'] ?? r['name'] ?? '').toString();
    bool strActive(Map<String, dynamic> r) =>
        asBool(r['is_enabled_effective'] ?? r['is_active'] ?? r['active']);
    int strOrder(Map<String, dynamic> r) =>
        (r['sort_order_effective'] ?? r['sort_order'] as num?)?.toInt() ?? 0;

    final activities = (json['activities'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((r) => CatalogActivityItem(
              id: (r['id'] ?? '').toString(),
              name: strName(r),
              description: r['description']?.toString(),
              isActive: strActive(r),
              sortOrder: strOrder(r),
            ))
        .toList();

    // Create whitelist of valid activity IDs to prevent global data leakage.
    // Use aliases to handle id shape differences (e.g. ACT-TYPE-123 vs 123).
    final validActivityIds = <String>{};
    for (final activity in activities) {
      validActivityIds.addAll(_activityIdAliases(activity.id));
    }

    final subcategories = (json['subcategories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((r) {
          final actId = (r['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map((r) => CatalogSubcategoryItem(
              id: (r['id'] ?? '').toString(),
              activityId: (r['activity_id'] ?? '').toString(),
              name: strName(r),
              description: r['description']?.toString(),
              isActive: strActive(r),
              sortOrder: strOrder(r),
            ))
        .toList();

    final purposes = (json['purposes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((r) {
          final actId = (r['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map((r) => CatalogPurposeItem(
              id: (r['id'] ?? '').toString(),
              activityId: (r['activity_id'] ?? '').toString(),
              subcategoryId: r['subcategory_id']?.toString(),
              name: strName(r),
              isActive: strActive(r),
              sortOrder: strOrder(r),
            ))
        .toList();

    final topics = (json['topics'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((r) => CatalogTopicItem(
              id: (r['id'] ?? '').toString(),
              type: r['type']?.toString(),
              name: strName(r),
              description: r['description']?.toString(),
              isActive: strActive(r),
              sortOrder: strOrder(r),
            ))
        .toList();

    final relations = (json['rel_activity_topics'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((r) {
          final actId = (r['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map((r) => CatalogRelationItem(
              activityId: (r['activity_id'] ?? '').toString(),
              topicId: (r['topic_id'] ?? '').toString(),
              isActive: asBool(r['is_active'] ?? r['active']),
            ))
        .toList();

    final results = (json['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((r) => CatalogResultItem(
              id: (r['id'] ?? '').toString(),
              category: (r['category'] ?? '').toString(),
              name: strName(r),
              description: r['description']?.toString(),
              isActive: strActive(r),
              sortOrder: strOrder(r),
            ))
        .toList();

    final assistants =
        (json['assistants'] as List? ?? json['attendees'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((r) => CatalogAssistantItem(
                  id: (r['id'] ?? r['attendee_id'] ?? '').toString(),
                  type: (r['type'] ?? '').toString(),
                  name: strName(r),
                  description: r['description']?.toString(),
                  isActive: strActive(r),
                  sortOrder: strOrder(r),
                ))
            .toList();

    return CatalogData(
      activities: activities,
      subcategories: subcategories,
      purposes: purposes,
      topics: topics,
      results: results,
      assistants: assistants,
      relations: relations,
    );
  }

  factory CatalogData.fromEditorJson(Map<String, dynamic> json) {
    final activities = (json['activities'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogActivityItem.fromJson)
        .toList();
    final subcategories = (json['subcategories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogSubcategoryItem.fromJson)
        .toList();
    final purposes = (json['purposes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogPurposeItem.fromJson)
        .toList();
    final topics = (json['topics'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogTopicItem.fromJson)
        .toList();
    final relations = (json['rel_activity_topics'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogRelationItem.fromJson)
        .toList();

    final results = (json['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogResultItem.fromJson)
        .toList();

    final assistants =
        (json['assistants'] as List? ?? json['attendees'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogAssistantItem.fromJson)
            .toList();

    return CatalogData(
      activities: activities,
      subcategories: subcategories,
      purposes: purposes,
      topics: topics,
      results: results,
      assistants: assistants,
      relations: relations,
    );
  }

  factory CatalogData.fromBundle(CatalogBundle bundle) {
    final activities = bundle.effective.entities.activities
        .map(
          (row) => CatalogActivityItem(
            id: (row['id'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            description: row['description']?.toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    // Create whitelist of valid activity IDs from this bundle to prevent global data leakage.
    // Use aliases to handle id shape differences (e.g. ACT-TYPE-123 vs 123).
    final validActivityIds = <String>{};
    for (final activity in activities) {
      validActivityIds.addAll(_activityIdAliases(activity.id));
    }

    final subcategories = bundle.effective.entities.subcategories
        .where((row) {
          final actId = (row['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map(
          (row) => CatalogSubcategoryItem(
            id: (row['id'] ?? '').toString(),
            activityId: (row['activity_id'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            description: row['description']?.toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final purposes = bundle.effective.entities.purposes
        .where((row) {
          final actId = (row['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map(
          (row) => CatalogPurposeItem(
            id: (row['id'] ?? '').toString(),
            activityId: (row['activity_id'] ?? '').toString(),
            subcategoryId: row.containsKey('subcategory_id')
                ? row['subcategory_id']?.toString()
                : null,
            name: (row['name'] ?? '').toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final topics = bundle.effective.entities.topics
        .map(
          (row) => CatalogTopicItem(
            id: (row['id'] ?? '').toString(),
            type: row['type']?.toString(),
            name: (row['name'] ?? '').toString(),
            description: row['description']?.toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final results = bundle.effective.entities.results
        .map(
          (row) => CatalogResultItem(
            id: (row['id'] ?? '').toString(),
            category: (row['category'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            description: row['description']?.toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final assistants = bundle.effective.entities.assistants
        .map(
          (row) => CatalogAssistantItem(
            id: (row['id'] ?? row['attendee_id'] ?? '').toString(),
            type: (row['type'] ?? '').toString(),
            name: (row['name'] ?? '').toString(),
            description: row['description']?.toString(),
            isActive: (row['active'] as bool?) ?? true,
            sortOrder: (row['order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    final relations = bundle.effective.relations.activityToTopicsSuggested
        .where((row) {
          final actId = (row['activity_id'] ?? '').toString();
          // Keep only rows linked to activities present in this project catalog.
          return _matchesKnownActivityId(actId, validActivityIds);
        })
        .map(
          (row) => CatalogRelationItem(
            activityId: (row['activity_id'] ?? '').toString(),
            topicId: (row['topic_id'] ?? '').toString(),
            isActive: (row['active'] as bool?) ?? true,
          ),
        )
        .toList();

    return CatalogData(
      activities: activities,
      subcategories: subcategories,
      purposes: purposes,
      topics: topics,
      results: results,
      assistants: assistants,
      relations: relations,
    );
  }

  factory CatalogData.fromBundleJson(Map<String, dynamic> json) {
    final bundle = CatalogBundle.fromJson(json);
    return CatalogData.fromBundle(bundle);
  }

  factory CatalogData.empty() {
    return CatalogData(
      activities: const [],
      subcategories: const [],
      purposes: const [],
      topics: const [],
      results: const [],
      assistants: const [],
      relations: const [],
    );
  }
}

class CatalogActivityItem {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CatalogActivityItem({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogActivityItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogActivityItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogSubcategoryItem {
  final String id;
  final String activityId;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CatalogSubcategoryItem({
    required this.id,
    required this.activityId,
    required this.name,
    required this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogSubcategoryItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogSubcategoryItem(
      id: (json['id'] ?? '').toString(),
      activityId: (json['activity_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogPurposeItem {
  final String id;
  final String activityId;
  final String? subcategoryId;
  final String name;
  final bool isActive;
  final int sortOrder;

  CatalogPurposeItem({
    required this.id,
    required this.activityId,
    required this.subcategoryId,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogPurposeItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogPurposeItem(
      id: (json['id'] ?? '').toString(),
      activityId: (json['activity_id'] ?? '').toString(),
      subcategoryId: json['subcategory_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogTopicItem {
  final String id;
  final String? type;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CatalogTopicItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogTopicItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogTopicItem(
      id: (json['id'] ?? '').toString(),
      type: json['type']?.toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogRelationItem {
  final String activityId;
  final String topicId;
  final bool isActive;

  CatalogRelationItem({
    required this.activityId,
    required this.topicId,
    required this.isActive,
  });

  factory CatalogRelationItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogRelationItem(
      activityId: (json['activity_id'] ?? '').toString(),
      topicId: (json['topic_id'] ?? '').toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
    );
  }
}

class CatalogResultItem {
  final String id;
  final String category;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CatalogResultItem({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogResultItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogResultItem(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatalogAssistantItem {
  final String id;
  final String type;
  final String name;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CatalogAssistantItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.isActive,
    required this.sortOrder,
  });

  factory CatalogAssistantItem.fromJson(Map<String, dynamic> json) {
    bool parseActive(dynamic raw) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return true;
    }

    return CatalogAssistantItem(
      id: (json['id'] ?? json['attendee_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      isActive: parseActive(json['is_active'] ?? json['active']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class CatItem {
  final String id;
  final String name;

  CatItem({
    required this.id,
    required this.name,
  });
}

class CatalogAdminHookResult {
  final bool supported;
  final bool success;
  final String message;
  final String? versionId;

  const CatalogAdminHookResult({
    required this.supported,
    required this.success,
    required this.message,
    this.versionId,
  });
}

// Fallback de último recurso — coincide con el bundle asset y el seed de producción.
// ignore: unused_element
const _catalogFallbackJson = '''
{
  "activities": [
    {"id": "CAM",  "name": "Caminamiento",                "is_active": true, "sort_order": 0},
    {"id": "REU",  "name": "Reunión",                     "is_active": true, "sort_order": 1},
    {"id": "ASP",  "name": "Asamblea Protocolizada",      "is_active": true, "sort_order": 2},
    {"id": "CIN",  "name": "Consulta Indígena",           "is_active": true, "sort_order": 3},
    {"id": "SOC",  "name": "Socialización",               "is_active": true, "sort_order": 4},
    {"id": "AIN",  "name": "Acompañamiento Institucional","is_active": true, "sort_order": 5}
  ],
  "subcategories": [
    {"id": "CAM_DDV", "activity_id": "CAM", "name": "Verificación de DDV",         "is_active": true, "sort_order": 0},
    {"id": "CAM_MAR", "activity_id": "CAM", "name": "Marcaje de afectaciones",     "is_active": true, "sort_order": 1},
    {"id": "CAM_ACC", "activity_id": "CAM", "name": "Revisión de accesos / BDT",   "is_active": true, "sort_order": 2},
    {"id": "REU_TEC", "activity_id": "REU", "name": "Técnica / Interinstitucional","is_active": true, "sort_order": 0},
    {"id": "REU_INF", "activity_id": "REU", "name": "Informativa",                 "is_active": true, "sort_order": 1},
    {"id": "REU_SEG", "activity_id": "REU", "name": "Seguimiento / Evaluación",    "is_active": true, "sort_order": 2},
    {"id": "ASP_1AP", "activity_id": "ASP", "name": "1ª Asamblea Protocolizada",   "is_active": true, "sort_order": 0},
    {"id": "ASP_2AP", "activity_id": "ASP", "name": "2ª Asamblea Protocolizada",   "is_active": true, "sort_order": 1},
    {"id": "CIN_INF", "activity_id": "CIN", "name": "Etapa Informativa",           "is_active": true, "sort_order": 0},
    {"id": "CIN_CON", "activity_id": "CIN", "name": "Construcción de Acuerdos",    "is_active": true, "sort_order": 1},
    {"id": "SOC_PRE", "activity_id": "SOC", "name": "Presentación Comunitaria",    "is_active": true, "sort_order": 0},
    {"id": "AIN_TEC", "activity_id": "AIN", "name": "Técnico",                     "is_active": true, "sort_order": 0},
    {"id": "AIN_SOC", "activity_id": "AIN", "name": "Social",                      "is_active": true, "sort_order": 1}
  ],
  "purposes": [
    {"id": "AFEC_VER_CAM",  "activity_id": "CAM", "subcategory_id": "CAM_DDV", "name": "Verificación de afectaciones",          "is_active": true, "sort_order": 0},
    {"id": "DDV_MAR_CAM",   "activity_id": "CAM", "subcategory_id": "CAM_MAR", "name": "Marcaje o actualización de DDV / trazo", "is_active": true, "sort_order": 0},
    {"id": "PRS_GEN_REU",   "activity_id": "REU", "subcategory_id": "REU_INF", "name": "Presentación general del proyecto",      "is_active": true, "sort_order": 0},
    {"id": "COOR_INST_REU", "activity_id": "REU", "subcategory_id": "REU_TEC", "name": "Coordinación institucional",             "is_active": true, "sort_order": 0},
    {"id": "PRS_GEN_ASP",   "activity_id": "ASP", "subcategory_id": "ASP_1AP", "name": "Presentación general del proyecto",      "is_active": true, "sort_order": 0},
    {"id": "COP_FIR_ASP",   "activity_id": "ASP", "subcategory_id": "ASP_2AP", "name": "Obtención de anuencia o firma de COP",   "is_active": true, "sort_order": 0}
  ],
  "topics": [
    {"id": "TOP_GAL",  "type": "Tecnico",       "name": "Gálibos ferroviarios",     "is_active": true, "sort_order": 0},
    {"id": "TOP_TEN",  "type": "Social/Agrario","name": "Tenencia de la tierra",    "is_active": true, "sort_order": 1},
    {"id": "TOP_AVA",  "type": "Social/Agrario","name": "Avalúos y pagos",          "is_active": true, "sort_order": 2},
    {"id": "TOP_ARB",  "type": "Ambiental",     "name": "Arbolado / vegetación",    "is_active": true, "sort_order": 3},
    {"id": "TOP_CONS", "type": "Indigena",      "name": "Consulta previa",          "is_active": true, "sort_order": 4}
  ],
  "rel_activity_topics": [
    {"activity_id": "CAM", "topic_id": "TOP_GAL",  "is_active": true},
    {"activity_id": "CAM", "topic_id": "TOP_TEN",  "is_active": true},
    {"activity_id": "CAM", "topic_id": "TOP_ARB",  "is_active": true},
    {"activity_id": "REU", "topic_id": "TOP_AVA",  "is_active": true},
    {"activity_id": "ASP", "topic_id": "TOP_TEN",  "is_active": true},
    {"activity_id": "CIN", "topic_id": "TOP_CONS", "is_active": true}
  ]
}
''';
