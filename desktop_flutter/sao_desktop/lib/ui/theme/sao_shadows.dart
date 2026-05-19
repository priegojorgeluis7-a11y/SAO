// lib/ui/theme/sao_shadows.dart
import 'package:flutter/material.dart';
import 'sao_colors.dart';

/// Sombras centralizadas de SAO
class SaoShadows {
  SaoShadows._();

  // ============================================================
  // ELEVACIONES (Material Design)
  // ============================================================
  static const double elevationNone = 0.0;
  static const double elevationSm = 1.0;
  static const double elevationMd = 2.0;
  static const double elevationLg = 4.0;
  static const double elevationXl = 8.0;

  // ============================================================
  // BOX SHADOWS PERSONALIZADAS
  // ============================================================
  
  // Sombras sutiles para profundidad
  static final List<BoxShadow> sm = [
    BoxShadow(
      color: SaoColors.gray900.withValues(alpha: 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> md = [
    BoxShadow(
      color: SaoColors.gray900.withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> lg = [
    BoxShadow(
      color: SaoColors.gray900.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  // Aliases legacy (compatibilidad)
  static final List<BoxShadow> cardShadow = sm;
  static final List<BoxShadow> dialogShadow = lg;
}
