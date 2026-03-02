// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

/// Paleta de colores centralizada de la app
class AppColors {
  AppColors._(); // Constructor privado para prevenir instanciación

  // Grises (Tailwind-inspired)
  static const gray50 = Color(0xFFF8FAFC);
  static const gray100 = Color(0xFFF1F5F9);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFCBD5E1);
  static const gray400 = Color(0xFF94A3B8);
  static const gray500 = Color(0xFF64748B);
  static const gray600 = Color(0xFF475569);
  static const gray700 = Color(0xFF334155);
  static const gray800 = Color(0xFF1E293B);
  static const gray900 = Color(0xFF0F172A);

  // Primarios
  static const primary = Color(0xFF111827);
  static const primaryLight = Color(0xFF374151);
  static const onPrimary = Colors.white;

  // Niveles de riesgo
  static const riskLow = Color(0xFF16A34A);      // 🟢 Verde
  static const riskMedium = Color(0xFFF59E0B);   // 🟡 Amarillo
  static const riskHigh = Color(0xFFF97316);     // 🟠 Naranja
  static const riskCritical = Color(0xFFDC2626); // 🔴 Rojo

  // Backgrounds de riesgo (con opacidad)
  static final riskLowBg = riskLow.withOpacity(0.14);
  static final riskMediumBg = riskMedium.withOpacity(0.14);
  static final riskHighBg = riskHigh.withOpacity(0.14);
  static final riskCriticalBg = riskCritical.withOpacity(0.14);

  // Alertas
  static const alertBg = Color(0xFFFFFBEB);
  static const alertBorder = Color(0xFFFDE68A);
  static const alertText = Color(0xFF92400E);

  // Estados
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // Superficie
  static const surface = Colors.white;
  static const surfaceDim = gray50;
  static const border = gray200;
  static const borderStrong = gray300;
}
