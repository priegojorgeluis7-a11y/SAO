// lib/core/theme/app_typography.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos de tipografía centralizados
class AppTypography {
  AppTypography._();

  // Títulos de secciones
  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
    letterSpacing: 0.2,
  );

  static const pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
  );

  // Cuerpo de texto
  static const bodyText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.gray700,
  );

  static const bodyTextBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.gray900,
  );

  // Hints y subtextos
  static const hint = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.gray500,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.gray600,
  );

  // Botones y chips
  static const buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const chipText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  // Alertas
  static const alertText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.alertText,
  );

  // Badges y métricas
  static const badgeText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const metricValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
  );

  static const metricLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.gray600,
    letterSpacing: 0.8,
  );
}
