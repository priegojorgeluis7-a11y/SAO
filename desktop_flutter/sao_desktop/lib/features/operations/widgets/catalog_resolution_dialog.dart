// lib/features/operations/widgets/catalog_resolution_dialog.dart
//
// Dialog for resolving CUSTOM_* catalog values in a synced activity.
// Allows admin to approve (add to catalog) or replace with existing values.
//
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/repositories/backend_api_client.dart';

/// Shows the [CatalogResolutionDialog] for the given [activity].
/// Returns `true` if changes were saved (caller should refresh).
Future<bool> showCatalogResolutionDialog(
  BuildContext context, {
  required ActivityWithDetails activity,
  required List<Map<String, dynamic>> catalogActivities,
  required List<Map<String, dynamic>> catalogSubcategories,
  required List<Map<String, dynamic>> catalogPurposes,
  required List<Map<String, dynamic>> catalogTopics,
  required List<Map<String, dynamic>> catalogResults,
  required List<Map<String, dynamic>> catalogAttendees,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => CatalogResolutionDialog(
      activity: activity,
      catalogActivities: catalogActivities,
      catalogSubcategories: catalogSubcategories,
      catalogPurposes: catalogPurposes,
      catalogTopics: catalogTopics,
      catalogResults: catalogResults,
      catalogAttendees: catalogAttendees,
    ),
  );
  return result ?? false;
}

class _CustomField {
  final String fieldKey;
  final String label;
  final String customId;
  final String customName;
  String? replacementId;
  String? replacementName;
  /// For list fields (topics/attendees), the old_id to match
  final String? oldId;
  /// 'approve' to add to catalog, 'replace' to use existing, null = pending
  String? action;

  _CustomField({
    required this.fieldKey,
    required this.label,
    required this.customId,
    required this.customName,
    this.oldId,
  });
}

class CatalogResolutionDialog extends StatefulWidget {
  final ActivityWithDetails activity;
  final List<Map<String, dynamic>> catalogActivities;
  final List<Map<String, dynamic>> catalogSubcategories;
  final List<Map<String, dynamic>> catalogPurposes;
  final List<Map<String, dynamic>> catalogTopics;
  final List<Map<String, dynamic>> catalogResults;
  final List<Map<String, dynamic>> catalogAttendees;

  const CatalogResolutionDialog({
    super.key,
    required this.activity,
    required this.catalogActivities,
    required this.catalogSubcategories,
    required this.catalogPurposes,
    required this.catalogTopics,
    required this.catalogResults,
    required this.catalogAttendees,
  });

  @override
  State<CatalogResolutionDialog> createState() =>
      _CatalogResolutionDialogState();
}

class _CatalogResolutionDialogState extends State<CatalogResolutionDialog> {
  late List<_CustomField> _fields;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fields = _extractCustomFields();
  }

  List<_CustomField> _extractCustomFields() {
    final payload = widget.activity.wizardPayload ?? {};
    final fields = <_CustomField>[];

    // Check simple fields
    for (final entry in [
      ('activity', 'Actividad'),
      ('subcategory', 'Subcategoría'),
      ('purpose', 'Propósito'),
      ('result', 'Resultado'),
    ]) {
      final value = payload[entry.$1];
      if (value is Map<String, dynamic>) {
        final id = (value['id'] ?? '').toString();
        if (id.startsWith('CUSTOM_')) {
          fields.add(_CustomField(
            fieldKey: entry.$1,
            label: entry.$2,
            customId: id,
            customName: (value['name'] ?? id).toString(),
          ));
        }
      }
    }

    // Check list fields
    for (final entry in [
      ('topics', 'Tema'),
      ('attendees', 'Asistente'),
    ]) {
      final list = payload[entry.$1];
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = (item['id'] ?? '').toString();
            if (id.startsWith('CUSTOM_')) {
              fields.add(_CustomField(
                fieldKey: entry.$1,
                label: entry.$2,
                customId: id,
                customName: (item['name'] ?? id).toString(),
                oldId: id,
              ));
            }
          }
        }
      }
    }

    return fields;
  }

  List<Map<String, dynamic>> _catalogForField(String fieldKey) {
    return switch (fieldKey) {
      'activity' => widget.catalogActivities,
      'subcategory' => widget.catalogSubcategories,
      'purpose' => widget.catalogPurposes,
      'topics' => widget.catalogTopics,
      'result' => widget.catalogResults,
      'attendees' => widget.catalogAttendees,
      _ => const [],
    };
  }

  bool get _allResolved => _fields.every((f) => f.action != null);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: AppColors.warning, size: 22),
          SizedBox(width: 8),
          Text('Resolver valores de catálogo'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta actividad tiene valores creados en campo que no '
                        'existen en el catálogo oficial. Puedes aprobarlos para '
                        'agregarlos al catálogo o reemplazarlos con valores existentes.',
                        style: TextStyle(fontSize: 13, color: AppColors.gray700),
                      ),
                    ),
                  ],
                ),
              ),
              if (_fields.isEmpty) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'No se encontraron valores custom pendientes.',
                    style: TextStyle(color: AppColors.gray500),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                ..._fields.map(_buildFieldCard),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_allResolved && !_isSaving) ? _save : null,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 16),
          label: const Text('Aplicar cambios'),
        ),
      ],
    );
  }

  Widget _buildFieldCard(_CustomField field) {
    final catalog = _catalogForField(field.fieldKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: field type + custom value
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    field.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"${field.customName}"',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${field.customId}',
              style: const TextStyle(fontSize: 11, color: AppColors.gray400),
            ),
            const SizedBox(height: 10),
            // Action radio buttons
            Row(
              children: [
                Expanded(
                  child: _ActionRadio(
                    icon: Icons.add_circle_outline,
                    label: 'Aprobar como nuevo',
                    description: 'Se agregará al catálogo oficial',
                    selected: field.action == 'approve',
                    onTap: () => setState(() {
                      field.action = 'approve';
                      field.replacementId = null;
                      field.replacementName = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionRadio(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Reemplazar',
                    description: 'Usar valor existente del catálogo',
                    selected: field.action == 'replace',
                    onTap: () => setState(() {
                      field.action = 'replace';
                    }),
                  ),
                ),
              ],
            ),
            // Replacement dropdown (only when 'replace' is selected)
            if (field.action == 'replace') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: field.replacementId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Seleccionar valor existente',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                items: catalog
                    .map((item) => DropdownMenuItem<String>(
                          value: item['id']?.toString(),
                          child: Text(
                            item['name']?.toString() ?? item['id'].toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    field.replacementId = value;
                    field.replacementName = catalog
                        .where((item) => item['id']?.toString() == value)
                        .map((item) =>
                            item['name']?.toString() ?? item['id'].toString())
                        .firstOrNull;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Validate all replace actions have a selection
    for (final field in _fields) {
      if (field.action == 'replace' && field.replacementId == null) {
        setState(() {
          _error =
              'Selecciona un valor de reemplazo para "${field.customName}"';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final uuid = widget.activity.activity.id;
      final replacements = <String, dynamic>{};

      for (final field in _fields) {
        if (field.action == 'approve') {
          // For approve, we keep the custom name but can optionally add to catalog
          // The flag will be cleared — admin accepted the value as-is
          continue;
        }
        if (field.action == 'replace') {
          if (field.oldId != null) {
            // List field (topics/attendees)
            final list = replacements[field.fieldKey] as List? ?? [];
            list.add({
              'old_id': field.oldId,
              'id': field.replacementId,
              'name': field.replacementName,
            });
            replacements[field.fieldKey] = list;
          } else {
            // Simple field
            replacements[field.fieldKey] = {
              'id': field.replacementId,
              'name': field.replacementName,
            };
          }
        }
      }

      // Try to add approved items to the catalog via editor endpoints
      for (final field in _fields) {
        if (field.action != 'approve') continue;
        try {
          await _addToCatalog(field);
        } catch (_) {
          // Non-blocking — the value stays in the activity either way
        }
      }

      await const BackendApiClient().patchJson(
        '/api/v1/activities/$uuid/resolve-catalog',
        {
          'replacements': replacements,
          'clear_catalog_flag': true,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Error al guardar: $e';
        });
      }
    }
  }

  Future<void> _addToCatalog(_CustomField field) async {
    final entityMap = {
      'activity': 'activities',
      'subcategory': 'subcategories',
      'purpose': 'purposes',
      'topics': 'topics',
      'result': 'results',
      'attendees': 'attendees',
    };
    final entity = entityMap[field.fieldKey];
    if (entity == null) return;

    final payload = <String, dynamic>{
      'name': field.customName,
      'is_enabled': true,
    };

    // Add parent references for cascaded entities
    final wp = widget.activity.wizardPayload ?? {};
    if (field.fieldKey == 'subcategory') {
      final act = wp['activity'];
      if (act is Map) payload['activity_id'] = act['id'];
    } else if (field.fieldKey == 'purpose') {
      final sub = wp['subcategory'];
      if (sub is Map) payload['subcategory_id'] = sub['id'];
      final act = wp['activity'];
      if (act is Map) payload['activity_id'] = act['id'];
    }

    await const BackendApiClient().postJson(
      '/api/v1/catalog/editor/$entity',
      payload,
    );
  }
}

class _ActionRadio extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ActionRadio({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.gray200,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppColors.primary.withOpacity(0.04)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.gray400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.primary : AppColors.gray700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(fontSize: 10, color: AppColors.gray400),
            ),
          ],
        ),
      ),
    );
  }
}
