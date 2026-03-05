import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sao_desktop/catalog/status_catalog.dart';
import 'package:sao_desktop/data/repositories/catalog_bundle_models.dart';

CatalogBundle _bundleWithWorkflow(Map<String, dynamic> workflow) {
  return CatalogBundle.fromJson(
    <String, dynamic>{
      'schema': 'sao.catalog.bundle.v1',
      'meta': <String, dynamic>{'project_id': 'TMQ'},
      'effective': <String, dynamic>{
        'entities': <String, dynamic>{
          'activities': <Map<String, dynamic>>[],
          'subcategories': <Map<String, dynamic>>[],
          'purposes': <Map<String, dynamic>>[],
          'topics': <Map<String, dynamic>>[],
          'results': <Map<String, dynamic>>[],
          'assistants': <Map<String, dynamic>>[],
        },
        'relations': <String, dynamic>{
          'activity_to_topics_suggested': <Map<String, dynamic>>[],
        },
        'rules': <String, dynamic>{
          'workflow': workflow,
        },
      },
      'editor': <String, dynamic>{},
    },
  );
}

void main() {
  group('StatusCatalog desktop catalog-driven transitions', () {
    test('reads transitions from workflow.global and enforces roles', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'global': <String, dynamic>{
            'transitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'from': 'nuevo',
                'to': <String>['en_revision', 'rechazado'],
                'roles': <String>['coordinador', 'admin'],
              },
            ],
          },
        },
      );

      final allowed = StatusCatalog.nextStatesFor(
        status: 'nuevo',
        role: 'coordinador',
        catalog: bundle,
      );
      final denied = StatusCatalog.nextStatesFor(
        status: 'nuevo',
        role: 'operativo',
        catalog: bundle,
      );

      expect(allowed, contains('en_revision'));
      expect(allowed, contains('rechazado'));
      expect(denied, isEmpty);
    });

    test('uses activityType override when present', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'global': <String, dynamic>{
            'transitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'from': 'borrador',
                'to': <String>['nuevo'],
              }
            ],
          },
          'by_activity_type': <String, dynamic>{
            'CAM': <String, dynamic>{
              'transitions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'from': 'borrador',
                  'to': <String>['en_revision'],
                }
              ],
            }
          },
        },
      );

      final generic = StatusCatalog.nextStatesFor(
        status: 'borrador',
        role: 'operativo',
        catalog: bundle,
      );
      final typed = StatusCatalog.nextStatesFor(
        status: 'borrador',
        role: 'operativo',
        activityType: 'CAM',
        catalog: bundle,
      );

      expect(generic, contains('nuevo'));
      expect(generic, isNot(contains('en_revision')));
      expect(typed, contains('en_revision'));
    });

    test('supports legacy states-next workflow format', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'states': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'borrador',
              'next': <String>['nuevo', 'en_revision'],
            },
          ],
        },
      );

      final next = StatusCatalog.nextStatesFor(
        status: 'borrador',
        role: 'operativo',
        catalog: bundle,
      );

      expect(next, contains('nuevo'));
      expect(next, contains('en_revision'));
    });

    test('enforces required_permissions with role catalog', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'global': <String, dynamic>{
            'transitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'from': 'en_revision',
                'to': <String>['aprobado'],
                'required_permissions': <String>['approve_activity'],
              },
            ],
          },
        },
      );

      final coordinator = StatusCatalog.nextStatesFor(
        status: 'en_revision',
        role: 'coordinador',
        catalog: bundle,
      );
      final operativo = StatusCatalog.nextStatesFor(
        status: 'en_revision',
        role: 'operativo',
        catalog: bundle,
      );

      expect(coordinator, contains('aprobado'));
      expect(operativo, isNot(contains('aprobado')));
    });

    test('maps next state labels and transition checks', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'global': <String, dynamic>{
            'transitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'from': 'nuevo',
                'to': <String>['en_revision', 'rechazado'],
              },
            ],
          },
        },
      );

      final labels = StatusCatalog.nextStateLabels(
        fromId: 'nuevo',
        role: 'coordinador',
        catalog: bundle,
      );

      expect(labels, contains('En Revisión'));
      expect(labels, contains('Rechazado'));
      expect(
        StatusCatalog.canTransitionTo(
          fromId: 'nuevo',
          toId: 'en_revision',
          role: 'coordinador',
          catalog: bundle,
        ),
        isTrue,
      );
      expect(
        StatusCatalog.canTransitionTo(
          fromId: 'nuevo',
          toId: 'aprobado',
          role: 'coordinador',
          catalog: bundle,
        ),
        isFalse,
      );
    });
  });

  group('StatusCatalog helper methods', () {
    test('finders and collections are consistent', () {
      expect(StatusCatalog.findById('aprobado')?.label, 'Aprobado');
      expect(StatusCatalog.findById('no_existe'), isNull);
      expect(StatusCatalog.findByLabel('en revisión')?.id, 'en_revision');
      expect(StatusCatalog.findByLabel('desconocido'), isNull);

      expect(StatusCatalog.ids, contains('borrador'));
      expect(StatusCatalog.labels, contains('Borrador'));
      expect(StatusCatalog.activeStates.every((s) => !s.isTerminal), isTrue);
      expect(StatusCatalog.terminalStates.every((s) => s.isTerminal), isTrue);
      expect(StatusCatalog.orderedByFlow.first.id, 'borrador');
    });

    test('supports single-string to transition target', () {
      final bundle = _bundleWithWorkflow(
        <String, dynamic>{
          'global': <String, dynamic>{
            'transitions': <Map<String, dynamic>>[
              <String, dynamic>{
                'from': 'nuevo',
                'to': 'en_revision',
              },
            ],
          },
        },
      );

      final next = StatusCatalog.nextStatesFor(
        status: 'nuevo',
        role: 'operativo',
        catalog: bundle,
      );

      expect(next, equals(const <String>['en_revision']));
    });

    test('dropdown items expose ids and labels', () {
      final byId = StatusCatalog.dropdownItems();
      final byLabel = StatusCatalog.dropdownItems(useId: false);

      expect(byId, hasLength(StatusCatalog.all.length));
      expect(byLabel, hasLength(StatusCatalog.all.length));
      expect(byId.first.value, StatusCatalog.all.first.id);
      expect(byLabel.first.value, StatusCatalog.all.first.label);
    });

    testWidgets('badge renders uppercase label for known and unknown status',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(child: Text('host')),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusCatalog.badge('aprobado'),
                StatusCatalog.badge('unknown_status'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('APROBADO'), findsOneWidget);
      // Unknown status falls back to `nuevo`.
      expect(find.text('NUEVO'), findsOneWidget);
    });
  });
}
