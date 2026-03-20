// lib/core/utils/format_utils.dart
/// Utilidades de formato de fecha, hora y PK compartidas en toda la app.

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

/// Formatea un PK en metros como "142+900". Devuelve "" si es null.
String formatPk(int? pk, {String ifNull = ''}) {
  if (pk == null) return ifNull;
  return '${pk ~/ 1000}+${(pk % 1000).toString().padLeft(3, '0')}';
}

/// Formatea PK con prefijo " · PK " para uso en líneas de texto. Devuelve "" si es null.
String formatPkInline(int? pk) {
  if (pk == null) return '';
  return ' · PK ${formatPk(pk)}';
}
