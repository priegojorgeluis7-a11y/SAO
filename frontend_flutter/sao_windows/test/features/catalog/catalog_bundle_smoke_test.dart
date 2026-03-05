// test/features/catalog/catalog_bundle_smoke_test.dart
//
// Smoke test: verifica que el bundle de catálogo empaquetado en assets
// se parsea correctamente y provee actividades via CatalogData.
//
// Criterio de F1.1: activity_catalog.dart eliminado; la fuente canónica
// de tipos de actividad es CatalogRepository.activities (bundle-driven).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/catalog/status_catalog.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogBundle smoke (F1.1)', () {
    late Map<String, dynamic> bundleJson;

    setUpAll(() {
      // Resolve asset path relative to the package root (where pubspec.yaml lives).
      final packageRoot = Directory.current.path.endsWith('test')
          ? Directory.current.parent.path
          : Directory.current.path;
      final file = File('$packageRoot/assets/base_seed_catalog.bundle.json');
      expect(file.existsSync(), isTrue,
          reason: 'Bundle asset not found at ${file.path}');
      bundleJson = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('bundle has sao.catalog.bundle.v1 schema', () {
      expect(bundleJson['schema'], equals('sao.catalog.bundle.v1'));
    });

    test('CatalogData.fromJson parses bundle and returns non-empty activities', () {
      final data = CatalogData.fromJson(bundleJson);
      expect(data.actividades, isNotEmpty,
          reason: 'Bundle debe contener al menos un tipo de actividad');
    });

    test('workflow exists in effective rules bundle', () {
      final data = CatalogData.fromJson(bundleJson);
      final workflow = data.rules['workflow'];
      expect(workflow, isA<Map>(),
          reason: 'El bundle debe incluir rules.workflow');

      final workflowMap = workflow as Map;
      final global = workflowMap['global'];
      expect(global, isA<Map>(),
          reason: 'workflow.global debe existir para transiciones default');

      final transitions = (global as Map)['transitions'];
      expect(transitions, isA<List>());
      expect((transitions as List), isNotEmpty,
          reason: 'workflow.global.transitions debe traer transiciones');
    });

      test('effective includes color_tokens and form_fields', () {
        final effective = (bundleJson['effective'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
        expect(effective['color_tokens'], isA<Map>(),
          reason: 'El bundle debe incluir effective.color_tokens');
        expect(effective['form_fields'], isA<List>(),
          reason: 'El bundle debe incluir effective.form_fields');
      });

    test('known status returns at least one transition', () {
      final data = CatalogData.fromJson(bundleJson);
      final next = StatusCatalog.nextStatesFor(
        status: 'nuevo',
        role: 'coordinador',
        catalog: data,
      );

      expect(next, isNotEmpty,
          reason: 'Un status conocido debe devolver >= 1 transición');
    });

    test('activityType-specific workflow overrides global transitions', () {
      final data = CatalogData.fromJson(bundleJson);
      final generic = StatusCatalog.nextStatesFor(
        status: 'borrador',
        role: 'operativo',
        catalog: data,
      );
      final byType = StatusCatalog.nextStatesFor(
        status: 'borrador',
        role: 'operativo',
        activityType: 'CAM',
        catalog: data,
      );

      expect(generic, contains('nuevo'));
      expect(generic, isNot(contains('en_revision')));
      expect(byType, contains('en_revision'),
          reason: 'Si hay workflow por tipo, debe respetar activityType');
    });

    test('returns empty when role has no permission', () {
      final data = CatalogData.fromJson(bundleJson);
      final next = StatusCatalog.nextStatesFor(
        status: 'nuevo',
        role: 'operativo',
        catalog: data,
      );

      expect(next, isEmpty,
          reason: 'Si el rol no está permitido por la transición, retorna vacío');
    });

    test('each activity has id and label', () {
      final data = CatalogData.fromJson(bundleJson);
      for (final item in data.actividades) {
        expect(item.id, isNotEmpty, reason: 'CatItem.id no debe ser vacío');
        expect(item.label, isNotEmpty, reason: 'CatItem.label no debe ser vacío');
        expect(item.icon, isA<IconData>());
      }
    });

  });
}
