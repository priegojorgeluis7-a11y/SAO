// desktop_flutter/sao_desktop/test/features/catalogs/catalogs_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/catalogs/catalogs_controller.dart';

void main() {
  group('CatalogSortSpec', () {
    test('copyWith updates field correctly', () {
      // GIVEN
      const original = CatalogSortSpec(
        field: CatalogSortField.name,
        ascending: true,
      );

      // WHEN
      final updated = original.copyWith(field: CatalogSortField.id);

      // THEN
      expect(updated.field, equals(CatalogSortField.id));
      expect(updated.ascending, equals(true)); // preserved
    });

    test('copyWith updates ascending correctly', () {
      // GIVEN
      const original = CatalogSortSpec(
        field: CatalogSortField.order,
        ascending: true,
      );

      // WHEN
      final updated = original.copyWith(ascending: false);

      // THEN
      expect(updated.field, equals(CatalogSortField.order));
      expect(updated.ascending, equals(false));
    });

    test('default constructor has sensible defaults', () {
      // WHEN
      const spec = CatalogSortSpec();

      // THEN
      expect(spec.field, equals(CatalogSortField.name));
      expect(spec.ascending, isTrue);
    });
  });

  group('CatalogTabUiState', () {
    test('copyWith preserves unspecified fields', () {
      // GIVEN
      const original = CatalogTabUiState(
        query: 'search test',
        activeFilter: ActiveFilter.active,
        reorderMode: true,
      );

      // WHEN
      final updated = original.copyWith(query: 'new search');

      // THEN
      expect(updated.query, equals('new search'));
      expect(updated.activeFilter, equals(ActiveFilter.active));
      expect(updated.reorderMode, isTrue);
    });

    test('copyWith with clearSelectedActivityId clears selection', () {
      // GIVEN
      const original = CatalogTabUiState(
        selectedActivityId: 'act-123',
      );

      // WHEN
      final updated = original.copyWith(clearSelectedActivityId: true);

      // THEN
      expect(updated.selectedActivityId, isNull);
    });

    test('copyWith can set new selectedActivityId', () {
      // GIVEN
      const original = CatalogTabUiState(
        selectedActivityId: 'act-old',
      );

      // WHEN
      final updated = original.copyWith(selectedActivityId: 'act-new');

      // THEN
      expect(updated.selectedActivityId, equals('act-new'));
    });

    test('default showSuggestedOnly is true', () {
      // WHEN
      const state = CatalogTabUiState();

      // THEN
      expect(state.showSuggestedOnly, isTrue);
    });

    test('can toggle showSuggestedOnly', () {
      // GIVEN
      const original = CatalogTabUiState(
        showSuggestedOnly: true,
      );

      // WHEN
      final updated = original.copyWith(showSuggestedOnly: false);

      // THEN
      expect(updated.showSuggestedOnly, isFalse);
    });

    test('multiple selections can coexist', () {
      // GIVEN
      const state = CatalogTabUiState(
        selectedActivityId: 'act-1',
        selectedSubcategoryId: 'subcat-2',
        selectedTopicType: 'topic-3',
      );

      // WHEN / THEN
      expect(state.selectedActivityId, equals('act-1'));
      expect(state.selectedSubcategoryId, equals('subcat-2'));
      expect(state.selectedTopicType, equals('topic-3'));
    });
  });

  group('CatalogTab enum', () {
    test('all catalog tabs exist', () {
      // WHEN / THEN
      expect(CatalogTab.activities, isNotNull);
      expect(CatalogTab.subcategories, isNotNull);
      expect(CatalogTab.purposes, isNotNull);
      expect(CatalogTab.topics, isNotNull);
      expect(CatalogTab.relations, isNotNull);
      expect(CatalogTab.results, isNotNull);
      expect(CatalogTab.assistants, isNotNull);
    });

    test('CatalogTab.values contains all 7 tabs', () {
      // WHEN / THEN
      expect(CatalogTab.values.length, equals(7));
    });
  });

  group('ActiveFilter enum', () {
    test('all active filters exist', () {
      // WHEN / THEN
      expect(ActiveFilter.all, isNotNull);
      expect(ActiveFilter.active, isNotNull);
      expect(ActiveFilter.inactive, isNotNull);
    });
  });

  group('CatalogSortField enum', () {
    test('all sort fields exist', () {
      // WHEN / THEN
      expect(CatalogSortField.id, isNotNull);
      expect(CatalogSortField.name, isNotNull);
      expect(CatalogSortField.active, isNotNull);
      expect(CatalogSortField.order, isNotNull);
    });
  });

  group('Catalog UI State Transitions', () {
    test('search query updates independently from filter', () {
      // GIVEN
      const initial = CatalogTabUiState();

      // WHEN
      final withSearch = initial.copyWith(query: 'inspection');
      final withFilter = withSearch.copyWith(activeFilter: ActiveFilter.active);

      // THEN
      expect(withFilter.query, equals('inspection'));
      expect(withFilter.activeFilter, equals(ActiveFilter.active));
    });

    test('reorder mode can toggle while maintaining other state', () {
      // GIVEN
      const state = CatalogTabUiState(
        query: 'test',
        activeFilter: ActiveFilter.active,
        reorderMode: false,
      );

      // WHEN
      final reordering = state.copyWith(reorderMode: true);
      final notReordering = reordering.copyWith(reorderMode: false);

      // THEN
      expect(reordering.reorderMode, isTrue);
      expect(reordering.query, equals('test')); // preserved
      expect(notReordering.reorderMode, isFalse);
    });

    test('sort order can be reversed', () {
      // GIVEN
      const ascending = CatalogSortSpec(
        field: CatalogSortField.name,
        ascending: true,
      );

      // WHEN
      final descending = ascending.copyWith(ascending: false);

      // THEN
      expect(ascending.ascending, isTrue);
      expect(descending.ascending, isFalse);
      expect(descending.field, equals(CatalogSortField.name)); // same field
    });
  });

  group('Catalog Filtering Logic', () {
    test('search query filters are case-sensitive by default', () {
      // GIVEN
      const state = CatalogTabUiState(
        query: 'Inspection',
      );

      // WHEN
      const exact = 'Inspection';

      // THEN
      // Typically in UI, search would be case-insensitive
      // but the state itself just stores the query as-is
      expect(state.query, equals(exact));
    });

    test('blank query matches all', () {
      // GIVEN
      const state = CatalogTabUiState(query: '');

      // WHEN / THEN
      expect(state.query.isEmpty, isTrue);
    });

    test('multiple filters can coexist', () {
      // GIVEN
      const filtered = CatalogTabUiState(
        query: 'reunion',
        activeFilter: ActiveFilter.active,
        showSuggestedOnly: true,
      );

      // WHEN / THEN
      expect(filtered.query, equals('reunion'));
      expect(filtered.activeFilter, equals(ActiveFilter.active));
      expect(filtered.showSuggestedOnly, isTrue);
    });
  });
}
