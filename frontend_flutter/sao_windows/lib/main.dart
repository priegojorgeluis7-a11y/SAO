import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/di/service_locator.dart';
import 'features/auth/data/auth_provider.dart';
import 'features/evidence/data/evidence_upload_retry_worker.dart';
import 'features/sync/services/auto_sync_service.dart';
import 'core/notifications/push_notifications_service.dart';
import 'app.dart';

Future<void> _bootstrapDependencies() async {
  await setupServiceLocator();
  await getIt<PushNotificationsService>().ensureInitialized();
  getIt<EvidenceUploadRetryWorker>().start();
  getIt<AutoSyncService>().start();
}

List<Override> _buildProviderOverrides() {
  return [
    authServiceProvider.overrideWithValue(getIt()),
    biometricServiceProvider.overrideWithValue(getIt()),
    connectivityServiceProvider.overrideWithValue(getIt()),
  ];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _bootstrapDependencies();

  runApp(
    ProviderScope(
      overrides: _buildProviderOverrides(),
      child: const App(),
    ),
  );
}
