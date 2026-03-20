class CatalogUpdateSummary {
  final int upserts;
  final int deletes;

  const CatalogUpdateSummary({
    required this.upserts,
    required this.deletes,
  });

  bool get hasChanges => (upserts + deletes) > 0;

  String get shortLabel {
    if (!hasChanges) return 'Sin cambios';
    return '$upserts alta/actualizacion, $deletes baja(s)';
  }
}

CatalogUpdateSummary summarizeCatalogDiff(Map<String, dynamic>? diff) {
  if (diff == null) {
    return const CatalogUpdateSummary(upserts: 0, deletes: 0);
  }

  final changesRaw = diff['changes'];
  if (changesRaw is! Map<String, dynamic>) {
    return const CatalogUpdateSummary(upserts: 0, deletes: 0);
  }

  var upserts = 0;
  var deletes = 0;

  for (final entry in changesRaw.entries) {
    final value = entry.value;
    if (value is! Map<String, dynamic>) continue;

    final upsertsRaw = value['upserts'];
    if (upsertsRaw is List) {
      upserts += upsertsRaw.length;
    }

    final deletesRaw = value['deletes'];
    if (deletesRaw is List) {
      deletes += deletesRaw.length;
    }
  }

  return CatalogUpdateSummary(upserts: upserts, deletes: deletes);
}
