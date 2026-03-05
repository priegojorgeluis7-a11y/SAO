// test/core/di/service_locator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/di/service_locator.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ServiceLocator', () {
    tearDown(() async {
      await resetServiceLocator();
    });

    test('setup initializes all dependencies', () async {
      await setupServiceLocator(prewarmCatalog: false);

      expect(getIt.isRegistered<AppDb>(), isTrue);
      expect(getIt.isRegistered<CatalogRepository>(), isTrue);
    });

    test('can retrieve database instance', () async {
      await setupServiceLocator(prewarmCatalog: false);

      final db = getIt<AppDb>();
      expect(db, isNotNull);
    });

    test('catalog repository is registered without prewarm', () async {
      await setupServiceLocator(prewarmCatalog: false);

      final catalogRepo = getIt<CatalogRepository>();
      expect(catalogRepo.isReady, isFalse);
    });

    test('reset clears all dependencies', () async {
      await setupServiceLocator(prewarmCatalog: false);
      await resetServiceLocator();

      expect(getIt.isRegistered<AppDb>(), isFalse);
    });
  });
}
