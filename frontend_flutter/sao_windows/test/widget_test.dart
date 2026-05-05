// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sao_windows/app.dart';
import 'package:sao_windows/core/di/service_locator.dart';
import 'package:sao_windows/core/routing/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies before running tests
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await setupServiceLocator(prewarmCatalog: false);
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Smoke test')),
          ),
        ),
      ],
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [goRouterProvider.overrideWithValue(router)],
        child: const App(),
      ),
    );

    // Verify that app loads (just basic smoke test)
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Smoke test'), findsOneWidget);
  });
}
