import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/catalog/state/catalog_sync_controller.dart';
import '../../features/auth/application/auth_providers.dart';
import '../theme/sao_colors.dart';

class CatalogBootstrapScreen extends ConsumerStatefulWidget {
  final String projectId;
  final Widget childWhenReady;

  const CatalogBootstrapScreen({
    super.key,
    required this.projectId,
    required this.childWhenReady,
  });

  @override
  ConsumerState<CatalogBootstrapScreen> createState() =>
      _CatalogBootstrapScreenState();
}

class _CatalogBootstrapScreenState
    extends ConsumerState<CatalogBootstrapScreen> {
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSyncIfNeeded());
  }

  @override
  void didUpdateWidget(covariant CatalogBootstrapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _ran = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSyncIfNeeded());
    }
  }

  void _runSyncIfNeeded() {
    if (_ran) return;
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) return;

    _ran = true;

    ref.read(catalogSyncControllerProvider.notifier).sync(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState.isLoading) {
      return const _LoadingView();
    }

    if (!authState.isAuthenticated) {
      return const _LoadingView(message: 'Preparando acceso…');
    }

    if (!_ran) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSyncIfNeeded());
    }

    return widget.childWhenReady;
  }
}

class _LoadingView extends StatelessWidget {
  final String message;

  const _LoadingView({this.message = 'Cargando información y catálogos…'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: SaoColors.gray600),
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
    );
  }
}
