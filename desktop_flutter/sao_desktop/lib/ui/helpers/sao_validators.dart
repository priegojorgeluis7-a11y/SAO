// lib/ui/helpers/sao_validators.dart
/// Validadores centralizados del SAO
class SaoValidators {
  SaoValidators._();

  // ============================================================
  // VALIDADORES DE TEXTO
  // ============================================================
  
  /// Validar que el campo no esté vacío
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null 
          ? '$fieldName es requerido' 
          : 'Este campo es requerido';
    }
    return null;
  }

  /// Validar longitud mínima
  static String? minLength(String? value, int min, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length < min) {
      return fieldName != null
          ? '$fieldName debe tener al menos $min caracteres'
          : 'Debe tener al menos $min caracteres';
    }
    return null;
  }

  /// Validar longitud máxima
  static String? maxLength(String? value, int max, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length > max) {
      return fieldName != null
          ? '$fieldName no puede tener más de $max caracteres'
          : 'No puede tener más de $max caracteres';
    }
    return null;
  }

  /// Validar rango de longitud
  static String? lengthRange(String? value, int min, int max, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (value.length < min || value.length > max) {
      return fieldName != null
          ? '$fieldName debe tener entre $min y $max caracteres'
          : 'Debe tener entre $min y $max caracteres';
    }
    return null;
  }

  // ============================================================
  // VALIDADORES DE EMAIL Y CONTACTO
  // ============================================================
  
  /// Validar formato de email
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Ingresa un email válido';
    }
    return null;
  }

  /// Validar teléfono mexicano (10 dígitos)
  static String? phoneNumberMX(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final digits = value.replaceAll(RegExp(r'\D'), '');
    
    if (digits.length != 10) {
      return 'El teléfono debe tener 10 dígitos';
    }
    return null;
  }

  /// Validar teléfono genérico
  static String? phoneNumber(String? value, {int minDigits = 7, int maxDigits = 15}) {
    if (value == null || value.isEmpty) return null;
    
    final digits = value.replaceAll(RegExp(r'\D'), '');
    
    if (digits.length < minDigits || digits.length > maxDigits) {
      return 'Teléfono inválido';
    }
    return null;
  }

  // ============================================================
  // VALIDADORES NUMÉRICOS
  // ============================================================
  
  /// Validar que sea un número
  static String? number(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (num.tryParse(value) == null) {
      return fieldName != null
          ? '$fieldName debe ser un número'
          : 'Debe ser un número';
    }
    return null;
  }

  /// Validar que sea un número entero
  static String? integer(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (int.tryParse(value) == null) {
      return fieldName != null
          ? '$fieldName debe ser un número entero'
          : 'Debe ser un número entero';
    }
    return null;
  }

  /// Validar rango numérico
  static String? numberRange(String? value, num min, num max, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    final number = num.tryParse(value);
    if (number == null) {
      return 'Debe ser un número';
    }
    
    if (number < min || number > max) {
      return fieldName != null
          ? '$fieldName debe estar entre $min y $max'
          : 'Debe estar entre $min y $max';
    }
    return null;
  }

  /// Validar número mínimo
  static String? min(String? value, num min, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    final number = num.tryParse(value);
    if (number == null) return 'Debe ser un número';
    
    if (number < min) {
      return fieldName != null
          ? '$fieldName debe ser mayor o igual a $min'
          : 'Debe ser mayor o igual a $min';
    }
    return null;
  }

  /// Validar número máximo
  static String? max(String? value, num max, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    final number = num.tryParse(value);
    if (number == null) return 'Debe ser un número';
    
    if (number > max) {
      return fieldName != null
          ? '$fieldName debe ser menor o igual a $max'
          : 'Debe ser menor o igual a $max';
    }
    return null;
  }

  // ============================================================
  // VALIDADORES DE PATRONES
  // ============================================================
  
  /// Validar contra patrón regex personalizado
  static String? pattern(String? value, String pattern, String message) {
    if (value == null || value.isEmpty) return null;
    
    if (!RegExp(pattern).hasMatch(value)) {
      return message;
    }
    return null;
  }

  /// Validar solo letras
  static String? onlyLetters(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(value)) {
      return fieldName != null
          ? '$fieldName solo puede contener letras'
          : 'Solo puede contener letras';
    }
    return null;
  }

  /// Validar solo números
  static String? onlyDigits(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return fieldName != null
          ? '$fieldName solo puede contener números'
          : 'Solo puede contener números';
    }
    return null;
  }

  /// Validar alfanumérico
  static String? alphanumeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;
    
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
      return fieldName != null
          ? '$fieldName solo puede contener letras y números'
          : 'Solo puede contener letras y números';
    }
    return null;
  }

  // ============================================================
  // VALIDADORES DE FECHAS
  // ============================================================
  
  /// Validar que la fecha no sea futura
  static String? notFutureDate(DateTime? value, {String? fieldName}) {
    if (value == null) return null;
    
    if (value.isAfter(DateTime.now())) {
      return fieldName != null
          ? '$fieldName no puede ser una fecha futura'
          : 'No puede ser una fecha futura';
    }
    return null;
  }

  /// Validar que la fecha no sea pasada
  static String? notPastDate(DateTime? value, {String? fieldName}) {
    if (value == null) return null;
    
    if (value.isBefore(DateTime.now())) {
      return fieldName != null
          ? '$fieldName no puede ser una fecha pasada'
          : 'No puede ser una fecha pasada';
    }
    return null;
  }

  /// Validar rango de fechas
  static String? dateRange(DateTime? value, DateTime min, DateTime max, {String? fieldName}) {
    if (value == null) return null;
    
    if (value.isBefore(min) || value.isAfter(max)) {
      return fieldName != null
          ? '$fieldName debe estar entre ${min.day}/${min.month}/${min.year} y ${max.day}/${max.month}/${max.year}'
          : 'Fecha fuera de rango permitido';
    }
    return null;
  }

  // ============================================================
  // COMBINADORES DE VALIDADORES
  // ============================================================
  
  /// Combinar múltiples validadores
  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }

  /// Email requerido
  static String? requiredEmail(String? value) {
    return required(value, fieldName: 'Email') ?? email(value);
  }

  /// Teléfono requerido (México)
  static String? requiredPhone(String? value) {
    return required(value, fieldName: 'Teléfono') ?? phoneNumberMX(value);
  }

  /// Número entero requerido
  static String? requiredInteger(String? value, {String? fieldName}) {
    return required(value, fieldName: fieldName) ?? integer(value, fieldName: fieldName);
  }
}
