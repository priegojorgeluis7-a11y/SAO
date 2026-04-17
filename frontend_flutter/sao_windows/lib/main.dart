import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/service_locator.dart';
import 'features/auth/data/auth_provider.dart';
import 'features/evidence/data/evidence_upload_retry_worker.dart';
import 'features/sync/services/auto_sync_service.dart';
import 'core/notifications/push_notifications_service.dart';
import 'ui/theme/sao_colors.dart';
import 'app.dart';

Future<void> _bootstrapDependencies() async {
  await setupServiceLocator(prewarmCatalog: false);
}

Future<void> _bootstrapBackgroundServices() async {
  try {
    await getIt<PushNotificationsService>().ensureInitialized();
    getIt<EvidenceUploadRetryWorker>().start();
    getIt<AutoSyncService>().start();
  } catch (_) {
    // Keep the app responsive even if optional startup services fail.
  }
}

List<Override> _buildProviderOverrides() {
  return [
    authServiceProvider.overrideWithValue(getIt()),
    biometricServiceProvider.overrideWithValue(getIt()),
    connectivityServiceProvider.overrideWithValue(getIt()),
  ];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapHost());
}

class _BootstrapHost extends StatefulWidget {
  const _BootstrapHost();

  @override
  State<_BootstrapHost> createState() => _BootstrapHostState();
}

class _BootstrapHostState extends State<_BootstrapHost> {
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapDependencies().then((_) {
      unawaited(_bootstrapBackgroundServices());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupSplash();
        }

        if (snapshot.hasError) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: SaoColors.surface,
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 54,
                        color: Colors.redAccent,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No se pudo iniciar SAO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Cierra y vuelve a abrir la app.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return ProviderScope(
          overrides: _buildProviderOverrides(),
          child: const App(),
        );
      },
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: SaoColors.gray50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/branding/sao_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Iniciando SAO',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: SaoColors.gray900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preparando la aplicación…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: SaoColors.gray600),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
