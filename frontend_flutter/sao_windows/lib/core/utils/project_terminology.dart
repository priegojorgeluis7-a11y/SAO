bool usesSegmentTerminology(String? projectCode) {
  final normalized = (projectCode ?? '').trim().toUpperCase();
  return normalized == 'TSNL' || normalized == 'TQI';
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