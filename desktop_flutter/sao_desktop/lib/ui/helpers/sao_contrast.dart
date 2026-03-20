// lib/ui/helpers/sao_contrast.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Utilidades para garantizar buen contraste entre texto y fondo
/// Calcula si el texto debe ser oscuro o claro basado en la luminosidad del fondo
class SaoContrast {
  static const Color _darkText = Color(0xFF1E293B); // gray800
  static const Color _lightText = Colors.white;

  /// Calcula la luminosidad relativa de un color (0-1)
  /// Basado en la fórmula WCAG: https://www.w3.org/TR/WCAG20/#relativeluminancedef
  static double _getLuminance(Color color) {
    final red = _channelValue(color.red);
    final green = _channelValue(color.green);
    final blue = _channelValue(color.blue);

    // Fórmula de luminosidad relativa WCAG
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  /// Convierte un valor de canal (0-255) a su valor linearizado
  static double _channelValue(int value) {
    final normalized = value / 255.0;
    if (normalized <= 0.03928) {
      return normalized / 12.92;
    }
    return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Retorna el color de texto que proporciona mejor contraste
  /// para un fondo dado.
  /// - Si el fondo es claro → retorna texto oscuro
  /// - Si el fondo es oscuro → retorna texto claro
  static Color getContrastColor(Color backgroundColor) {
    final luminance = _getLuminance(backgroundColor);
    
    // Umbral empírico: 0.5 funciona bien como punto medio
    // Colores con luminance > 0.5 son "claros" → necesitan texto oscuro
    // Colores con luminance ≤ 0.5 son "oscuros" → necesitan texto claro
    return luminance > 0.5 ? _darkText : _lightText;
  }

  /// Retorna true si el fondo es "claro" (requiere texto oscuro)
  static bool isLightBackground(Color backgroundColor) {
    return _getLuminance(backgroundColor) > 0.5;
  }

  /// Retorna true si el fondo es "oscuro" (requiere texto claro)
  static bool isDarkBackground(Color backgroundColor) {
    return !isLightBackground(backgroundColor);
  }
}
