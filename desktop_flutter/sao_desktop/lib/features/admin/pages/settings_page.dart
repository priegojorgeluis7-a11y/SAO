import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/session_controller.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(adminBaseUrlProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuración',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textFor(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Backend URL: $baseUrl',
                style: TextStyle(color: AppColors.textFor(context)),
              ),
              const SizedBox(height: 6),
              Text(
                'Para cambiarla: --dart-define=SAO_BACKEND_URL=http://host:puerto',
                style: TextStyle(color: AppColors.textMutedFor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
