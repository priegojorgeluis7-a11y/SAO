import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin_shell.dart';
import 'login_page.dart';
import 'session_controller.dart';

class AdminRoot extends ConsumerWidget {
  const AdminRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    if (session.isAuthenticated) {
      return const AdminShell();
    }
    return const LoginPage();
  }
}
