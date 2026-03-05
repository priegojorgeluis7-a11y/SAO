import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/routing/auth_redirect_resolver.dart';
import 'package:sao_windows/features/auth/application/auth_controller.dart';
import 'package:sao_windows/features/auth/data/models/user.dart';

void main() {
  group('Router auth redirect', () {
    test('unauthenticated user is redirected to /auth/login on protected route', () {
      final redirect = resolveAuthRedirect(
        authStateAsync: const AsyncValue<AuthState>.data(AuthState.unauthenticated()),
        uri: Uri.parse('/agenda'),
      );

      expect(redirect, '/auth/login');
    });

    test('authenticated user on login is redirected to root shell', () {
      final redirect = resolveAuthRedirect(
        authStateAsync: AsyncValue<AuthState>.data(
          AuthState.authenticated(
            User(
              id: 'u1',
              email: 'user@sao.dev',
              fullName: 'User SAO',
              status: 'active',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ),
        uri: Uri.parse('/auth/login'),
      );

      expect(redirect, '/');
    });
  });
}
