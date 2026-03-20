// lib/ui/theme/sao_theme.dart
import 'package:flutter/material.dart';
import 'sao_colors.dart';
import 'sao_radii.dart';
import 'sao_spacing.dart';

/// Theme completo de SAO (compartido entre Mobile y Desktop)
/// Este ThemeData debe usarse en MaterialApp para garantizar consistencia
class SaoTheme {
  SaoTheme._();

  // ── Tokens dark ──────────────────────────────────────────────────────────
  static const _darkBg        = Color(0xFF0F172A); // slate-900
  static const _darkSurface   = Color(0xFF1E293B); // slate-800
  static const _darkBorder    = Color(0xFF334155); // slate-700
  static const _darkOnSurface = Color(0xFFF1F5F9); // slate-100
  static const _darkSubtext   = Color(0xFF94A3B8); // slate-400
  static const _darkPrimary   = Color(0xFFE2E8F0); // slate-200 (active/brand en dark)

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: _darkSurface,
        secondary: _darkSubtext,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        error: SaoColors.error,
        outline: _darkBorder,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: _darkOnSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: SaoSpacing.md,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkBorder),
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkBorder,
        selectedColor: _darkPrimary.withOpacity(0.20),
        disabledColor: _darkBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          side: const BorderSide(color: _darkBorder),
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _darkOnSurface,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _darkPrimary,
        ),
        checkmarkColor: _darkPrimary,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: _darkSurface,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: _darkSurface,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _darkBorder,
          borderRadius: BorderRadius.circular(SaoRadii.sm),
        ),
        textStyle: const TextStyle(color: _darkOnSurface, fontSize: 12),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // ============================================================
      // COLOR SCHEME
      // ============================================================
      colorScheme: const ColorScheme.light(
        primary: SaoColors.primary,
        onPrimary: SaoColors.onPrimary,
        secondary: SaoColors.gray600,
        surface: SaoColors.surface,
        error: SaoColors.error,
      ),

      // ============================================================
      // SCAFFOLD
      // ============================================================
      scaffoldBackgroundColor: SaoColors.gray50,

      // ============================================================
      // APP BAR
      // ============================================================
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: SaoColors.primary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: SaoColors.primary,
        ),
      ),

      // ============================================================
      // CARDS
      // ============================================================
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          side: const BorderSide(color: SaoColors.border),
        ),
      ),

      // ============================================================
      // INPUT DECORATION
      // ============================================================
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: SaoSpacing.md,
        ),
      ),

      // ============================================================
      // BUTTONS
      // ============================================================
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SaoColors.primary,
          foregroundColor: SaoColors.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SaoColors.primary,
          side: const BorderSide(color: SaoColors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.xxl,
            vertical: SaoSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
        ),
      ),

      // ============================================================
      // CHIPS
      // ============================================================
      chipTheme: ChipThemeData(
        backgroundColor: SaoColors.gray100,
        selectedColor: SaoColors.actionPrimary.withOpacity(0.16),
        disabledColor: SaoColors.gray200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          side: const BorderSide(color: SaoColors.border),
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SaoColors.gray800,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SaoColors.actionPrimary,
        ),
        checkmarkColor: SaoColors.actionPrimary,
      ),

      // ============================================================
      // DIVIDER
      // ============================================================
      dividerTheme: const DividerThemeData(
        color: SaoColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
