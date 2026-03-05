class CatalogBundle {
  final String schema;
  final Map<String, dynamic> meta;
  final CatalogEditor editor;
  final CatalogEffective effective;

  const CatalogBundle({
    required this.schema,
    required this.meta,
    required this.editor,
    required this.effective,
  });

  factory CatalogBundle.fromJson(Map<String, dynamic> json) {
    return CatalogBundle(
      schema: (json['schema'] ?? '').toString(),
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      editor: CatalogEditor.fromJson(
        (json['editor'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      effective: CatalogEffective.fromJson(
        (json['effective'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
    );
  }
}

class CatalogEffective {
  final EffectiveEntities entities;
  final EffectiveRelations relations;
  final Map<String, dynamic> colorTokens;
  final List<Map<String, dynamic>> formFields;
  final EffectiveRules rules;

  const CatalogEffective({
    required this.entities,
    required this.relations,
    required this.colorTokens,
    required this.formFields,
    required this.rules,
  });

  factory CatalogEffective.fromJson(Map<String, dynamic> json) {
    return CatalogEffective(
      entities: EffectiveEntities.fromJson(
        (json['entities'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      relations: EffectiveRelations.fromJson(
        (json['relations'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      colorTokens:
          (json['color_tokens'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      formFields: (json['form_fields'] as List?)
              ?.whereType<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[],
      rules: EffectiveRules.fromJson(
        (json['rules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
    );
  }
}

class EffectiveEntities {
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> subcategories;
  final List<Map<String, dynamic>> purposes;
  final List<Map<String, dynamic>> topics;
  final List<Map<String, dynamic>> results;
  final List<Map<String, dynamic>> assistants;

  const EffectiveEntities({
    required this.activities,
    required this.subcategories,
    required this.purposes,
    required this.topics,
    required this.results,
    required this.assistants,
  });

  factory EffectiveEntities.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parse(String key) {
      return (json[key] as List?)
              ?.whereType<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[];
    }

    return EffectiveEntities(
      activities: parse('activities'),
      subcategories: parse('subcategories'),
      purposes: parse('purposes'),
      topics: parse('topics'),
      results: parse('results'),
      assistants: parse('assistants'),
    );
  }
}

class EffectiveRelations {
  final List<Map<String, dynamic>> activityToTopicsSuggested;

  const EffectiveRelations({required this.activityToTopicsSuggested});

  factory EffectiveRelations.fromJson(Map<String, dynamic> json) {
    return EffectiveRelations(
      activityToTopicsSuggested: (json['activity_to_topics_suggested'] as List?)
              ?.whereType<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[],
    );
  }
}

class EffectiveRules {
  final WorkflowDefinition? workflow;
  final Map<String, dynamic> workflowJson;
  final Map<String, dynamic> cascades;
  final Map<String, dynamic> nullSemantics;
  final List<Map<String, dynamic>> constraints;
  final TopicPolicy topicPolicy;

  const EffectiveRules({
    this.workflow,
    required this.workflowJson,
    required this.cascades,
    required this.nullSemantics,
    required this.constraints,
    required this.topicPolicy,
  });

  factory EffectiveRules.fromJson(Map<String, dynamic> json) {
    final rawWorkflow = json['workflow'];
    return EffectiveRules(
      workflow: rawWorkflow is Map
        ? WorkflowDefinition.fromJson(rawWorkflow.cast<String, dynamic>())
          : null,
      workflowJson: rawWorkflow is Map
        ? rawWorkflow.cast<String, dynamic>()
        : const <String, dynamic>{},
      cascades: (json['cascades'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      nullSemantics:
          (json['null_semantics'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      constraints: (json['constraints'] as List?)
              ?.whereType<Map>()
              .map((entry) => entry.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[],
      topicPolicy: TopicPolicy.fromJson(
        (json['topic_policy'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
    );
  }
}

/// Single state definition in the activity workflow.
class WorkflowState {
  final String id;
  final int order;
  final bool terminal;
  final List<String> next;

  const WorkflowState({
    required this.id,
    required this.order,
    required this.terminal,
    required this.next,
  });

  factory WorkflowState.fromJson(Map<String, dynamic> json) {
    return WorkflowState(
      id: (json['id'] ?? '').toString(),
      order: (json['order'] as num?)?.toInt() ?? 0,
      terminal: (json['terminal'] as bool?) ?? false,
      next: (json['next'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

/// Full workflow state-machine parsed from effective.rules.workflow.
class WorkflowDefinition {
  final List<WorkflowState> states;

  const WorkflowDefinition({required this.states});

  factory WorkflowDefinition.fromJson(Map<String, dynamic> json) {
    return WorkflowDefinition(
      states: (json['states'] as List?)
              ?.whereType<Map>()
              .map((e) => WorkflowState.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }

  /// Returns the allowed next-state IDs for [statusId]. Empty list if terminal or unknown.
  List<String> nextStatesFor(String statusId) {
    try {
      return states.firstWhere((s) => s.id == statusId).next;
    } catch (_) {
      return const [];
    }
  }

  bool canTransitionTo(String from, String to) => nextStatesFor(from).contains(to);
}

class TopicPolicy {
  final String defaultMode;
  final Map<String, String> byActivity;

  const TopicPolicy({
    required this.defaultMode,
    required this.byActivity,
  });

  factory TopicPolicy.fromJson(Map<String, dynamic> json) {
    final rawByActivity = (json['by_activity'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return TopicPolicy(
      defaultMode: (json['default'] ?? 'any').toString(),
      byActivity: rawByActivity.map((key, value) => MapEntry(key, value.toString())),
    );
  }

  String modeFor(String activityId) {
    final normalized = activityId.trim();
    if (normalized.isEmpty) return defaultMode;
    return byActivity[normalized] ?? defaultMode;
  }
}

class CatalogEditor {
  final Map<String, dynamic> layers;
  final Map<String, dynamic> validation;
  final Map<String, dynamic> history;

  const CatalogEditor({
    required this.layers,
    required this.validation,
    required this.history,
  });

  factory CatalogEditor.fromJson(Map<String, dynamic> json) {
    return CatalogEditor(
      layers: (json['layers'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      validation: (json['validation'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      history: (json['history'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
  }
}
