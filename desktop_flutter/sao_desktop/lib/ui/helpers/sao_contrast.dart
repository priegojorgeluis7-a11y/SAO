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
    final red = _channelValue(color.r);
    final green = _channelValue(color.g);
    final blue = _channelValue(color.b);

    // Fórmula de luminosidad relativa WCAG
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  /// Convierte un valor de canal (0-255) a su valor linearizado
  static double _channelValue(double normalized) {
    if (normalized <= 0.03928) {
      return normalized / 12.92;
    }
    return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _contrastRatio(Color a, Color b) {
    final l1 = _getLuminance(a);
    final l2 = _getLuminance(b);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Retorna el color de texto que proporciona mejor contraste para un fondo.
  /// Si el fondo tiene transparencia, se mezcla primero contra `againstColor`
  /// para estimar el color visible real.
  static Color getContrastColor(
    Color backgroundColor, {
    Color againstColor = Colors.white,
  }) {
    final effectiveBackground = backgroundColor.a >= 1.0
        ? backgroundColor
        : Color.alphaBlend(backgroundColor, againstColor);

    final darkRatio = _contrastRatio(_darkText, effectiveBackground);
    final lightRatio = _contrastRatio(_lightText, effectiveBackground);

    return darkRatio >= lightRatio ? _darkText : _lightText;
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
