import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell.dart';
import 'app_login_page.dart';
import 'app_session_controller.dart';

/// Top-level routing widget for the normal (non-admin) app.
/// Shows a loading indicator while restoring the persisted session,
/// then routes to [AppLoginPage] or [AppShell] based on auth state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionControllerProvider);

    if (session.initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isAuthenticated) {
      return const AppShell();
    }

    return const AppLoginPage();
  }
}
