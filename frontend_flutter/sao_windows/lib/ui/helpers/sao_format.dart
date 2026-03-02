// lib/ui/helpers/sao_format.dart
import 'package:intl/intl.dart';

/// Helpers de formato centralizados del SAO
class SaoFormat {
  SaoFormat._();

  // ============================================================
  // FORMATOS DE FECHA Y HORA
  // ============================================================
  
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateTimeLongFormat = DateFormat('dd \'de\' MMMM yyyy HH:mm', 'es');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'es');

  /// Formatear fecha: 15/12/2024
  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  /// Formatear hora: 14:30
  static String time(DateTime? time) {
    if (time == null) return '-';
    return _timeFormat.format(time);
  }

  /// Formatear fecha y hora: 15/12/2024 14:30
  static String dateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _dateTimeFormat.format(dateTime);
  }

  /// Formatear fecha larga: 15 de diciembre 2024 14:30
  static String dateTimeLong(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return _dateTimeLongFormat.format(dateTime);
  }

  /// Formatear mes y año: diciembre 2024
  static String monthYear(DateTime? date) {
    if (date == null) return '-';
    return _monthYearFormat.format(date);
  }

  /// Formatear fecha relativa: "Hoy", "Ayer", "Hace 3 días"
  static String dateRelative(DateTime? date) {
    if (date == null) return '-';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);
    
    if (dateDay == today) return 'Hoy ${time(date)}';
    if (dateDay == yesterday) return 'Ayer ${time(date)}';
    
    final difference = today.difference(dateDay).inDays;
    if (difference < 7) return 'Hace $difference días';
    if (difference < 30) return 'Hace ${(difference / 7).floor()} semanas';
    if (difference < 365) return 'Hace ${(difference / 30).floor()} meses';
    
    return SaoFormat.date(date);
  }

  /// Formatear duración en minutos a formato legible: "2h 15m"
  static String duration(int? minutes) {
    if (minutes == null || minutes == 0) return '-';
    
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  // ============================================================
  // FORMATOS DE NÚMEROS
  // ============================================================
  
  static final NumberFormat _numberFormat = NumberFormat('#,##0', 'es');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );
  static final NumberFormat _percentFormat = NumberFormat.percentPattern('es');

  /// Formatear número entero: 1,234
  static String number(num? value) {
    if (value == null) return '-';
    return _numberFormat.format(value);
  }

  /// Formatear número decimal: 1,234.56
  static String decimal(num? value, {int decimals = 2}) {
    if (value == null) return '-';
    return NumberFormat('#,##0.${'0' * decimals}', 'es').format(value);
  }

  /// Formatear moneda: $1,234.56
  static String currency(num? value) {
    if (value == null) return '-';
    return _currencyFormat.format(value);
  }

  /// Formatear porcentaje: 45%
  static String percent(num? value) {
    if (value == null) return '-';
    return _percentFormat.format(value / 100);
  }

  // ============================================================
  // FORMATOS DE PKs Y CÓDIGOS
  // ============================================================
  
  /// Formatear PK (Primary Key): "OP-2024-001234"
  static String pk(String? prefix, int? number, {int digits = 6}) {
    if (number == null) return '-';
    final paddedNumber = number.toString().padLeft(digits, '0');
    final year = DateTime.now().year;
    return prefix != null ? '$prefix-$year-$paddedNumber' : '$year-$paddedNumber';
  }

  /// Formatear ID corto: "001234"
  static String shortId(int? number, {int digits = 6}) {
    if (number == null) return '-';
    return number.toString().padLeft(digits, '0');
  }

  /// Formatear UUID corto (primeros 8 caracteres)
  static String shortUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return '-';
    return uuid.length > 8 ? uuid.substring(0, 8).toUpperCase() : uuid.toUpperCase();
  }

  // ============================================================
  // FORMATOS DE TEXTO
  // ============================================================
  
  /// Capitalizar primera letra
  static String capitalize(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Título (capitalizar cada palabra)
  static String titleCase(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Truncar texto con elipsis
  static String truncate(String? text, int maxLength, {String ellipsis = '...'}) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$ellipsis';
  }

  /// Iniciales de nombre: "Juan Pérez" -> "JP"
  static String initials(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '';
    
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // ============================================================
  // FORMATOS DE ARCHIVOS
  // ============================================================
  
  /// Formatear tamaño de archivo: "1.5 MB"
  static String fileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '-';
    
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
  }

  /// Obtener extensión de archivo
  static String fileExtension(String? filename) {
    if (filename == null || !filename.contains('.')) return '';
    return filename.split('.').last.toUpperCase();
  }

  // ============================================================
  // VALIDACIONES Y FORMATOS DE CONTACTO
  // ============================================================
  
  /// Formatear teléfono mexicano: (555) 123-4567
  static String phone(String? phone) {
    if (phone == null || phone.isEmpty) return '-';
    
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  /// Formatear email (truncar si es muy largo)
  static String email(String? email, {int maxLength = 30}) {
    if (email == null || email.isEmpty) return '-';
    return truncate(email, maxLength);
  }
}
