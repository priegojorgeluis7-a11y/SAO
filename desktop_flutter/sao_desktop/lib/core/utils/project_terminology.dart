bool usesSegmentTerminology(String? projectCode) {
  return true;
}

String frontTerminology(
  String? projectCode, {
  bool plural = false,
  bool capitalize = false,
}) {
  final term = usesSegmentTerminology(projectCode)
      ? (plural ? 'segmentos' : 'segmento')
      : (plural ? 'frentes' : 'frente');
  if (!capitalize) return term;
  return '${term[0].toUpperCase()}${term.substring(1)}';
}

/// Converts stored front labels (F1, F2, Frente 1…) to segment labels (S1, S2…).
String toSegmentName(String value) {
  final trimmed = value.trim();
  final byPrefix = RegExp(r'^[Ff]([0-9]+)$');
  final byWord = RegExp(r'^[Ff]rente\s+([0-9]+)$', caseSensitive: false);
  final matchPrefix = byPrefix.firstMatch(trimmed);
  if (matchPrefix != null) return 'S${matchPrefix.group(1)}';
  final matchWord = byWord.firstMatch(trimmed);
  if (matchWord != null) return 'S${matchWord.group(1)}';
  return trimmed;
}
