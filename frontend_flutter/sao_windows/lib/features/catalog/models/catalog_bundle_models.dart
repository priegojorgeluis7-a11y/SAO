class CatalogBundle {
  final String schema;
  final Map<String, dynamic> meta;
  final CatalogEffective effective;
  final Map<String, dynamic> editor;

  const CatalogBundle({
    required this.schema,
    required this.meta,
    required this.effective,
    required this.editor,
  });

  factory CatalogBundle.fromJson(Map<String, dynamic> json) {
    return CatalogBundle(
      schema: (json['schema'] ?? '').toString(),
      meta: (json['meta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      effective: CatalogEffective.fromJson(
        (json['effective'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      ),
      editor: (json['editor'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schema': schema,
      'meta': meta,
      'effective': effective.toJson(),
      'editor': editor,
    };
  }
}

class CatalogEffective {
  final EffectiveEntities entities;
  final EffectiveRelations relations;
  final Map<String, dynamic> colorTokens;
  final List<Map<String, dynamic>> formFields;
  final Map<String, dynamic> rules;

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
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[],
      rules: (json['rules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
        'entities': entities.toJson(),
        'relations': relations.toJson(),
        'color_tokens': colorTokens,
        'form_fields': formFields,
        'rules': rules,
      };
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
              ?.whereType<Map<String, dynamic>>()
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

  Map<String, dynamic> toJson() => {
        'activities': activities,
        'subcategories': subcategories,
        'purposes': purposes,
        'topics': topics,
        'results': results,
        'assistants': assistants,
      };
}

class EffectiveRelations {
  final List<Map<String, dynamic>> activityToTopicsSuggested;

  const EffectiveRelations({required this.activityToTopicsSuggested});

  factory EffectiveRelations.fromJson(Map<String, dynamic> json) {
    return EffectiveRelations(
      activityToTopicsSuggested: (json['activity_to_topics_suggested'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[],
    );
  }

  Map<String, dynamic> toJson() => {
        'activity_to_topics_suggested': activityToTopicsSuggested,
      };
}
