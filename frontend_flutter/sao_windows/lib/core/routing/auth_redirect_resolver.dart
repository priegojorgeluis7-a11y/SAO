import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';

String? resolveAuthRedirect({
  required AsyncValue<AuthState> authStateAsync,
  required Uri uri,
}) {
  final authState = authStateAsync.asData?.value;
  final isAuthenticated = authState?.isAuthenticated == true;
  final requiresPinUnlock = authState?.requiresPinUnlock == true;
  final isLoading = authStateAsync.isLoading;

  final isLoginRoute = uri.path == '/login' || uri.path == '/auth/login';
  final isSignupRoute = uri.path == '/auth/signup';
  final isPinUnlockRoute = uri.path == '/auth/pin-unlock';
  final isTutorialRoute = uri.path == '/tutorial';
  final isTutorialGuest = uri.queryParameters['tutorial'] == '1';
  final isTutorialGuestShellRoute = isTutorialGuest &&
      (uri.path == '/' ||
          uri.path == '/sync' ||
          uri.path == '/agenda' ||
          uri.path == '/settings');

  if (isLoading) {
    return null;
  }

  // PIN bloqueado → forzar pantalla de desbloqueo
  if (requiresPinUnlock && !isPinUnlockRoute) {
    return '/auth/pin-unlock';
  }

  // No autenticado (ni PIN) → login
  if (!isAuthenticated &&
      !requiresPinUnlock &&
      !isLoginRoute &&
      !isSignupRoute &&
      !isPinUnlockRoute &&
      !isTutorialRoute &&
      !isTutorialGuestShellRoute) {
    return '/auth/login';
  }

  // Ya autenticado → salir de pantallas de auth
  if (isAuthenticated && (isLoginRoute || isSignupRoute || isPinUnlockRoute)) {
    return '/';
  }

  return null;
}
