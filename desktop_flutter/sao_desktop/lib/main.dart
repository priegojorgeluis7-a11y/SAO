import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'data/database/app_database.dart';
import 'features/admin/auth/admin_root.dart';
import 'features/auth/auth_gate.dart';
import 'ui/sao_ui.dart'; // 🎨 Design System unificado

Future<void> _initializeLocalization() async {
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
}

Future<AppDatabase> _createDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, 'sao_desktop.db');
  return AppDatabase(dbPath);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeLocalization();
  final database = await _createDatabase();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const SaoDesktopApp(),
    ),
  );
}

class SaoDesktopApp extends StatelessWidget {
  const SaoDesktopApp({super.key});

  static const bool _adminMode =
      bool.fromEnvironment('SAO_ADMIN_MODE', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAO - Sistema de Administración de Obras',
      debugShowCheckedModeBanner: false,
      theme: SaoTheme.lightTheme, // 🎨 Theme unificado Mobile/Desktop
      home: _adminMode ? const AdminRoot() : const AuthGate(),
    );
  }
}
