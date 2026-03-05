import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/repositories/catalog_bundle_models.dart';

void main() {
  group('CatalogBundle.fromJson', () {
    test('parses empty json gracefully', () {
      final bundle = CatalogBundle.fromJson(const {});
      expect(bundle.schema, '');
      expect(bundle.meta, isEmpty);
    });

    test('parses schema and meta', () {
      final bundle = CatalogBundle.fromJson(const {
        'schema': 'catalog-bundle-v2',
        'meta': {'project_id': 'TMQ', 'version': 3},
        'editor': {},
        'effective': {},
      });
      expect(bundle.schema, 'catalog-bundle-v2');
      expect(bundle.meta['project_id'], 'TMQ');
      expect(bundle.meta['version'], 3);
    });

    test('parses effective entities activities as raw maps', () {
      final bundle = CatalogBundle.fromJson({
        'schema': 'catalog-bundle-v2',
        'effective': {
          'entities': {
            'activities': [
              {
                'id': 'at-1',
                'code': 'INSP_CIVIL',
                'name': 'Inspección Civil',
                'is_active': true,
              },
              {
                'id': 'at-2',
                'code': 'ASAMBLEA',
                'name': 'Asamblea',
                'is_active': false,
              },
            ],
          },
        },
      });
      final types = bundle.effective.entities.activities;
      expect(types.length, 2);
      expect(types.first['code'], 'INSP_CIVIL');
      expect(types.first['name'], 'Inspección Civil');
      expect(types.first['is_active'], isTrue);
      expect(types.last['is_active'], isFalse);
    });

    test('parses color tokens', () {
      final bundle = CatalogBundle.fromJson({
        'effective': {
          'color_tokens': {
            'primary': '#111827',
            'success': '#10B981',
          },
        },
      });
      expect(bundle.effective.colorTokens['primary'], '#111827');
    });

    test('returns empty activities when entities missing', () {
      final bundle = CatalogBundle.fromJson(const {'effective': {}});
      expect(bundle.effective.entities.activities, isEmpty);
    });

    test('parses subcategories, purposes, topics', () {
      final bundle = CatalogBundle.fromJson({
        'effective': {
          'entities': {
            'subcategories': [
              {'id': 'sc-1', 'name': 'Vía', 'code': 'VIA'},
            ],
            'purposes': [
              {'id': 'p-1', 'name': 'Mantenimiento'},
            ],
            'topics': [
              {'id': 't-1', 'name': 'Durmientes'},
            ],
          },
        },
      });
      expect(bundle.effective.entities.subcategories.length, 1);
      expect(bundle.effective.entities.subcategories.first['code'], 'VIA');
      expect(bundle.effective.entities.purposes.length, 1);
      expect(bundle.effective.entities.topics.length, 1);
    });
  });

  group('CatalogEffective.fromJson', () {
    test('parses form_fields list', () {
      final effective = CatalogEffective.fromJson({
        'form_fields': [
          {'field_key': 'observations', 'label': 'Observaciones', 'type': 'text'},
          {'field_key': 'risk_level', 'label': 'Nivel de riesgo', 'type': 'select'},
        ],
      });
      expect(effective.formFields.length, 2);
      expect(effective.formFields.first['field_key'], 'observations');
    });

    test('returns empty form fields when missing', () {
      final effective = CatalogEffective.fromJson(const {});
      expect(effective.formFields, isEmpty);
    });

    test('parses relations activity_to_topics_suggested', () {
      final effective = CatalogEffective.fromJson({
        'relations': {
          'activity_to_topics_suggested': [
            {'activity_id': 'at-1', 'topic_id': 't-1'},
          ],
        },
      });
      expect(effective.relations.activityToTopicsSuggested.length, 1);
      expect(
        effective.relations.activityToTopicsSuggested.first['activity_id'],
        'at-1',
      );
    });
  });

  group('EffectiveRelations.fromJson', () {
    test('handles empty relations', () {
      final rel = EffectiveRelations.fromJson(const {});
      expect(rel.activityToTopicsSuggested, isEmpty);
    });
  });

  group('EffectiveRules and workflow domain', () {
    test('parses workflowJson and typed workflow definition', () {
      final rules = EffectiveRules.fromJson({
        'workflow': {
          'states': [
            {'id': 'nuevo', 'order': 1, 'terminal': false, 'next': ['en_revision']},
            {'id': 'en_revision', 'order': 2, 'terminal': false, 'next': ['aprobado', 'rechazado']},
          ],
          'global': {
            'transitions': [
              {'from': 'nuevo', 'to': ['en_revision']}
            ]
          }
        },
        'cascades': {'a': true},
        'null_semantics': {'empty_string': 'null'},
        'constraints': [
          {'id': 'c1', 'type': 'required'}
        ],
      });

      expect(rules.workflowJson, isNotEmpty);
      expect(rules.workflow, isNotNull);
      expect(rules.workflow!.nextStatesFor('nuevo'), contains('en_revision'));
      expect(rules.workflow!.canTransitionTo('en_revision', 'aprobado'), isTrue);
      expect(rules.workflow!.canTransitionTo('nuevo', 'rechazado'), isFalse);
      expect(rules.cascades['a'], isTrue);
      expect(rules.nullSemantics['empty_string'], 'null');
      expect(rules.constraints, hasLength(1));
    });

    test('handles empty workflow and unknown states safely', () {
      final rules = EffectiveRules.fromJson(const {});
      expect(rules.workflowJson, isEmpty);
      expect(rules.workflow, isNull);

      final wf = WorkflowDefinition.fromJson(const {'states': []});
      expect(wf.nextStatesFor('missing'), isEmpty);
      expect(wf.canTransitionTo('missing', 'any'), isFalse);
    });

    test('topic policy falls back to default and normalizes empty id', () {
      final policy = TopicPolicy.fromJson({
        'default': 'restricted',
        'by_activity': {'ACT_1': 'suggested_only'},
      });

      expect(policy.modeFor('ACT_1'), 'suggested_only');
      expect(policy.modeFor('ACT_2'), 'restricted');
      expect(policy.modeFor('   '), 'restricted');
    });
  });
}
