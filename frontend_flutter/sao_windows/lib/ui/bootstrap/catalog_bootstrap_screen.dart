import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/catalog/state/catalog_sync_controller.dart';
import '../../features/auth/application/auth_providers.dart';

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
    if (authState.isLoading || !authState.isAuthenticated) {
      return const _LoadingView();
    }

    if (!_ran) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSyncIfNeeded());
    }

    return widget.childWhenReady;
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Sincronizando catalogos...')),
    );
  }
}
