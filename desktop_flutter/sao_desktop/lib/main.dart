import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'core/config/data_mode.dart';
import 'core/session/session_migrator.dart';
import 'core/theme/theme_provider.dart';
import 'data/database/app_database.dart';
import 'features/admin/auth/admin_root.dart';
import 'features/auth/auth_gate.dart';
import 'ui/sao_ui.dart'; // Design System unificado

Future<void> _initializeLocalization() async {
  await initializeDateFormatting('es_MX');
  Intl.defaultLocale = 'es_MX';
}

Future<AppDatabase> _createDatabase() async => AppDatabase.memory();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeLocalization();

  // Desktop must run against real remote backend only.
  AppDataMode.requireRealBackendUrl();

  // Migrate legacy plain-text session file to OS credential vault (one-shot).
  await SessionMigrator.migrateIfNeeded();

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

class SaoDesktopApp extends ConsumerWidget {
  const SaoDesktopApp({super.key});

  static const bool _adminMode =
      bool.fromEnvironment('SAO_ADMIN_MODE', defaultValue: false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'SAO - Sistema de Administración de Obras',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: SaoTheme.lightTheme,
      darkTheme: SaoTheme.darkTheme,
      themeMode: themeMode,
      home: _adminMode ? const AdminRoot() : const AuthGate(),
    );
  }
}
