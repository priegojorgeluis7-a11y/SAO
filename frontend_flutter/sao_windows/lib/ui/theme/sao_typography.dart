// lib/ui/theme/sao_typography.dart
import 'package:flutter/material.dart';
import 'sao_colors.dart';

/// Estilos de tipografía centralizados de SAO
/// ⚠️ NO uses TextStyle inline en pantallas, usa SOLO estos tokens
class SaoTypography {
  SaoTypography._();

  static const bodySmall = bodyTextSmall;
  static const bodyMedium = bodyText;
  static const labelMedium = bodyTextBold;
  static const titleMedium = sectionTitle;

  // ============================================================
  // TÍTULOS
  // ============================================================
  static const pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: SaoColors.primary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: SaoColors.primary,
    letterSpacing: 0.2,
  );

  // ============================================================
  // JERARQUÍA OPERATIVA SAO (Proyecto > Frente > PK > Actividad)
  // ============================================================
  
  /// Título de Proyecto (TMQ, TAP, TSNL)
  static const projectTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: SaoColors.actionPrimary,
    letterSpacing: 0.5,
  );

  /// Título de Frente (Tenerías, Playa Grande)
  static const frontTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: SaoColors.gray900,
  );

  /// Etiqueta de PK (0+000.50, 1+250.00)
  static const pkLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: SaoColors.gray800,
    letterSpacing: 0.5,
    fontFamily: 'monospace',
  );

  // ============================================================
  // CUERPO DE TEXTO
  // ============================================================
  static const bodyText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SaoColors.gray700,
  );

  static const bodyTextBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: SaoColors.gray900,
  );

  static const bodyTextSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: SaoColors.gray700,
  );

  // ============================================================
  // HINTS Y SUBTEXTOS
  // ============================================================
  static const hint = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: SaoColors.gray500,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: SaoColors.gray600,
  );

  // ============================================================
  // BOTONES Y CHIPS
  // ============================================================
  static const buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static const chipText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  // ============================================================
  // ALERTAS
  // ============================================================
  static const alertText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: SaoColors.alertText,
  );

  // ============================================================
  // BADGES Y MÉTRICAS
  // ============================================================
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
    color: SaoColors.gray600,
    letterSpacing: 0.8,
  );

  // ============================================================
  // CARDS Y LISTAS
  // ============================================================
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: SaoColors.primary,
  );

  static const cardSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: SaoColors.gray600,
  );

  // ============================================================
  // MONOSPACE (para IDs, PKs, códigos)
  // ============================================================
  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w900,
    color: SaoColors.primary,
  );

  static const monoSmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: SaoColors.gray700,
  );
}
