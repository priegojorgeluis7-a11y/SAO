// lib/features/catalog/models/catalog_dto.dart

/// DTOs for catalog API operations (Phase 4A)
/// Matches backend schemas in app/schemas/catalog.py
library;


/// Catalog version metadata
class CatalogVersionDTO {
  final String id;
  final String projectId;
  final String versionNumber;
  final String status;
  final String? hash;
  final String? publishedById;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  const CatalogVersionDTO({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.status,
    this.hash,
    this.publishedById,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  factory CatalogVersionDTO.fromJson(Map<String, dynamic> json) {
    return CatalogVersionDTO(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      versionNumber: json['version_number'] as String,
      status: json['status'] as String,
      hash: json['hash'] as String?,
      publishedById: json['published_by_id'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

/// Activity type entity
class ActivityTypeDTO {
  final String id;
  final String versionId;
  final String code;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final bool requiresApproval;
  final int? maxDurationMinutes;
  final String? notificationEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityTypeDTO({
    required this.id,
    required this.versionId,
    required this.code,
    required this.name,
    this.description,
    this.icon,
    this.color,
    required this.sortOrder,
    required this.isActive,
    required this.requiresApproval,
    this.maxDurationMinutes,
    this.notificationEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityTypeDTO.fromJson(Map<String, dynamic> json) {
    return ActivityTypeDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      requiresApproval: json['requires_approval'] as bool? ?? false,
      maxDurationMinutes: json['max_duration_minutes'] as int?,
      notificationEmail: json['notification_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Event type entity
class EventTypeDTO {
  final String id;
  final String versionId;
  final String code;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final String? priority;
  final int sortOrder;
  final bool isActive;
  final bool autoCreateActivity;
  final bool requiresImmediateResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventTypeDTO({
    required this.id,
    required this.versionId,
    required this.code,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.priority,
    required this.sortOrder,
    required this.isActive,
    required this.autoCreateActivity,
    required this.requiresImmediateResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventTypeDTO.fromJson(Map<String, dynamic> json) {
    return EventTypeDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      priority: json['priority'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      autoCreateActivity: json['auto_create_activity'] as bool? ?? false,
      requiresImmediateResponse:
          json['requires_immediate_response'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Form field entity
class FormFieldDTO {
  final String id;
  final String versionId;
  final String entityType;
  final String typeId;
  final String key;
  final String label;
  final String? helpText;
  final String widget;
  final int sortOrder;
  final bool required;
  final String? validationRegex;
  final String? validationMessage;
  final int? minValue;
  final int? maxValue;
  final int? minLength;
  final int? maxLength;
  final List<Map<String, dynamic>>? options;
  final Map<String, dynamic>? visibleWhen;
  final Map<String, dynamic>? requiredWhen;
  final String? defaultValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FormFieldDTO({
    required this.id,
    required this.versionId,
    required this.entityType,
    required this.typeId,
    required this.key,
    required this.label,
    this.helpText,
    required this.widget,
    required this.sortOrder,
    required this.required,
    this.validationRegex,
    this.validationMessage,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.options,
    this.visibleWhen,
    this.requiredWhen,
    this.defaultValue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FormFieldDTO.fromJson(Map<String, dynamic> json) {
    return FormFieldDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      entityType: json['entity_type'] as String,
      typeId: json['type_id'] as String,
      key: json['key'] as String,
      label: json['label'] as String,
      helpText: json['help_text'] as String?,
      widget: json['widget'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      required: json['required'] as bool? ?? false,
      validationRegex: json['validation_regex'] as String?,
      validationMessage: json['validation_message'] as String?,
      minValue: json['min_value'] as int?,
      maxValue: json['max_value'] as int?,
      minLength: json['min_length'] as int?,
      maxLength: json['max_length'] as int?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      visibleWhen: json['visible_when'] as Map<String, dynamic>?,
      requiredWhen: json['required_when'] as Map<String, dynamic>?,
      defaultValue: json['default_value'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Workflow state entity
class WorkflowStateDTO {
  final String id;
  final String versionId;
  final String entityType;
  final String code;
  final String label;
  final String? color;
  final bool isInitial;
  final bool isFinal;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkflowStateDTO({
    required this.id,
    required this.versionId,
    required this.entityType,
    required this.code,
    required this.label,
    this.color,
    required this.isInitial,
    required this.isFinal,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkflowStateDTO.fromJson(Map<String, dynamic> json) {
    return WorkflowStateDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      entityType: json['entity_type'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      color: json['color'] as String?,
      isInitial: json['is_initial'] as bool? ?? false,
      isFinal: json['is_final'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Workflow transition entity
class WorkflowTransitionDTO {
  final String id;
  final String versionId;
  final String fromStateId;
  final String toStateId;
  final String label;
  final String? description;
  final List<int>? allowedRoles;
  final List<String>? requiredPermissions;
  final List<String>? requiredFields;
  final String? confirmMessage;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkflowTransitionDTO({
    required this.id,
    required this.versionId,
    required this.fromStateId,
    required this.toStateId,
    required this.label,
    this.description,
    this.allowedRoles,
    this.requiredPermissions,
    this.requiredFields,
    this.confirmMessage,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkflowTransitionDTO.fromJson(Map<String, dynamic> json) {
    return WorkflowTransitionDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      fromStateId: json['from_state_id'] as String,
      toStateId: json['to_state_id'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      allowedRoles: (json['allowed_roles'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      requiredPermissions: (json['required_permissions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      requiredFields: (json['required_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      confirmMessage: json['confirm_message'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Evidence rule entity
class EvidenceRuleDTO {
  final String id;
  final String versionId;
  final String entityType;
  final String typeId;
  final int minPhotos;
  final int? maxPhotos;
  final bool requiresGps;
  final bool requiresSignature;
  final List<String>? allowedFileTypes;
  final int maxFileSizeMb;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EvidenceRuleDTO({
    required this.id,
    required this.versionId,
    required this.entityType,
    required this.typeId,
    required this.minPhotos,
    this.maxPhotos,
    required this.requiresGps,
    required this.requiresSignature,
    this.allowedFileTypes,
    required this.maxFileSizeMb,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EvidenceRuleDTO.fromJson(Map<String, dynamic> json) {
    return EvidenceRuleDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      entityType: json['entity_type'] as String,
      typeId: json['type_id'] as String,
      minPhotos: json['min_photos'] as int? ?? 0,
      maxPhotos: json['max_photos'] as int?,
      requiresGps: json['requires_gps'] as bool? ?? true,
      requiresSignature: json['requires_signature'] as bool? ?? false,
      allowedFileTypes: (json['allowed_file_types'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      maxFileSizeMb: json['max_file_size_mb'] as int? ?? 10,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Checklist template entity
class ChecklistTemplateDTO {
  final String id;
  final String versionId;
  final String activityTypeId;
  final String name;
  final String? description;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChecklistTemplateDTO({
    required this.id,
    required this.versionId,
    required this.activityTypeId,
    required this.name,
    this.description,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChecklistTemplateDTO.fromJson(Map<String, dynamic> json) {
    return ChecklistTemplateDTO(
      id: json['id'] as String,
      versionId: json['version_id'] as String,
      activityTypeId: json['activity_type_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Complete catalog package (matches CatalogPackage from backend)
class CatalogPackageDTO {
  final String versionId;
  final String versionNumber;
  final String projectId;
  final String hash;
  final DateTime publishedAt;
  final List<ActivityTypeDTO> activityTypes;
  final List<EventTypeDTO> eventTypes;
  final List<FormFieldDTO> formFields;
  final List<WorkflowStateDTO> workflowStates;
  final List<WorkflowTransitionDTO> workflowTransitions;
  final List<EvidenceRuleDTO> evidenceRules;
  final List<ChecklistTemplateDTO> checklistTemplates;

  const CatalogPackageDTO({
    required this.versionId,
    required this.versionNumber,
    required this.projectId,
    required this.hash,
    required this.publishedAt,
    required this.activityTypes,
    required this.eventTypes,
    required this.formFields,
    required this.workflowStates,
    required this.workflowTransitions,
    required this.evidenceRules,
    required this.checklistTemplates,
  });

  factory CatalogPackageDTO.fromJson(Map<String, dynamic> json) {
    return CatalogPackageDTO(
      versionId: json['version_id'] as String,
      versionNumber: json['version_number'] as String,
      projectId: json['project_id'] as String,
      hash: json['hash'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      activityTypes: (json['activity_types'] as List<dynamic>)
          .map((e) => ActivityTypeDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventTypes: (json['event_types'] as List<dynamic>)
          .map((e) => EventTypeDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      formFields: (json['form_fields'] as List<dynamic>)
          .map((e) => FormFieldDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      workflowStates: (json['workflow_states'] as List<dynamic>)
          .map((e) => WorkflowStateDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      workflowTransitions: (json['workflow_transitions'] as List<dynamic>)
          .map((e) => WorkflowTransitionDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      evidenceRules: (json['evidence_rules'] as List<dynamic>)
          .map((e) => EvidenceRuleDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      checklistTemplates: (json['checklist_templates'] as List<dynamic>)
          .map((e) => ChecklistTemplateDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Response for check updates endpoint
class CatalogCheckUpdatesResponse {
  final bool updateAvailable;
  final String? latestHash;
  final String? latestVersionNumber;
  final DateTime? publishedAt;

  const CatalogCheckUpdatesResponse({
    required this.updateAvailable,
    this.latestHash,
    this.latestVersionNumber,
    this.publishedAt,
  });

  factory CatalogCheckUpdatesResponse.fromJson(Map<String, dynamic> json) {
    return CatalogCheckUpdatesResponse(
      updateAvailable: json['update_available'] as bool,
      latestHash: json['latest_hash'] as String?,
      latestVersionNumber: json['latest_version_number'] as String?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
    );
  }
}
