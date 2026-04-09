// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

import 'package:sao_desktop/features/auth/app_session_controller.dart';
import 'package:sao_desktop/main.dart';

class _FakeAppSessionController extends StateNotifier<AppSessionState>
    implements AppSessionController {
  _FakeAppSessionController()
      : super(
          const AppSessionState(
            initializing: false,
            loading: false,
            error: null,
            accessToken: 'test-token',
            user: AppUser(
              id: 'user-1',
              email: 'test@sao.dev',
              fullName: 'Test User',
              role: 'COORDINADOR',
              roles: ['COORDINADOR'],
            ),
          ),
        );

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('SaoDesktopApp renders root MaterialApp', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionControllerProvider.overrideWith(
            (ref) => _FakeAppSessionController(),
          ),
        ],
        child: const SaoDesktopApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
