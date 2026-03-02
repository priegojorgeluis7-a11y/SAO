sealed class CatalogSyncStatus {
  const CatalogSyncStatus();
}

class CatalogSyncIdle extends CatalogSyncStatus {
  const CatalogSyncIdle();
}

class CatalogSyncing extends CatalogSyncStatus {
  const CatalogSyncing();
}

class CatalogReady extends CatalogSyncStatus {
  final String versionId;
  const CatalogReady(this.versionId);
}

class CatalogSyncError extends CatalogSyncStatus {
  final String message;
  final bool canRetry;
  final bool canUseLocal;
  /// True when the failure is an expired/missing session rather than a
  /// catalog/network problem. The bootstrap screen uses this to call logout()
  /// so the router redirects to the login page cleanly.
  final bool isAuthError;

  const CatalogSyncError(
    this.message, {
    this.canRetry = true,
    this.canUseLocal = false,
    this.isAuthError = false,
  });
}
