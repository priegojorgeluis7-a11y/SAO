// lib/core/utils/format_utils.dart
// Utilidades de formato de fecha, hora y PK compartidas en toda la app.

/// Formatea DateTime como "dd/MM/yyyy".
String fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';

/// Formatea DateTime como "HH:mm". Devuelve "—" si es null.
String fmtTime(DateTime? dt) {
  if (dt == null) return '—';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Formatea DateTime como "dd/MM/yyyy HH:mm". Devuelve "—" si es null.
String fmtDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return '${fmtDate(dt)} ${fmtTime(dt)}';
}

/// Normaliza PK heredados o capturados como enteros cortos.
///
/// Compatibilidad histórica:
/// - 90   -> 90+000 -> 90000 metros
/// - 90250 -> 90+250 -> 90250 metros
int? normalizePkMeters(int? pk) {
  if (pk == null) return null;
  if (pk > 0 && pk < 1000) return pk * 1000;
  return pk;
}

/// Convierte texto o valores numéricos de PK a metros canónicos.
int? parsePkMeters(dynamic raw) {
  if (raw == null) return null;

  if (raw is int) {
    return normalizePkMeters(raw);
  }

  final value = raw.toString().trim().replaceAll(' ', '');
  if (value.isEmpty || value == '—') return null;

  final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(value);
  if (chainage != null) {
    final km = int.tryParse(chainage.group(1)!);
    final meters = int.tryParse(chainage.group(2)!.padRight(3, '0'));
    if (km == null || meters == null || meters > 999) return null;
    return (km * 1000) + meters;
  }

  final chainageNoMeters = RegExp(r'^(\d+)\+$').firstMatch(value);
  if (chainageNoMeters != null) {
    final km = int.tryParse(chainageNoMeters.group(1)!);
    if (km == null) return null;
    return km * 1000;
  }

  if (RegExp(r'^\d+$').hasMatch(value)) {
    final parsed = int.tryParse(value);
    if (parsed == null) return null;
    if (value.length <= 3) return parsed * 1000;
    return normalizePkMeters(parsed);
  }

  return null;
}

/// Formatea un PK en metros como "142+900". Devuelve "" si es null.
String formatPk(int? pk, {String ifNull = ''}) {
  final normalized = normalizePkMeters(pk);
  if (normalized == null) return ifNull;
  return '${normalized ~/ 1000}+${(normalized % 1000).toString().padLeft(3, '0')}';
}

/// Formatea PK con prefijo " · PK " para uso en líneas de texto. Devuelve "" si es null.
String formatPkInline(int? pk) {
  if (pk == null) return '';
  return ' · PK ${formatPk(pk)}';
}
