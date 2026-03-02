// test/core/di/service_locator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/di/service_locator.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';

void main() {
  group('ServiceLocator', () {
    tearDown(() async {
      await resetServiceLocator();
    });

    test('setup initializes all dependencies', () async {
      await setupServiceLocator();

      expect(getIt.isRegistered<AppDb>(), isTrue);
      expect(getIt.isRegistered<CatalogRepository>(), isTrue);
    });

    test('can retrieve database instance', () async {
      await setupServiceLocator();

      final db = getIt<AppDb>();
      expect(db, isNotNull);
    });

    test('catalog repository is pre-initialized', () async {
      await setupServiceLocator();

      final catalogRepo = getIt<CatalogRepository>();
      expect(catalogRepo.isReady, isTrue);
    });

    test('reset clears all dependencies', () async {
      await setupServiceLocator();
      await resetServiceLocator();

      expect(getIt.isRegistered<AppDb>(), isFalse);
    });
  });
}
