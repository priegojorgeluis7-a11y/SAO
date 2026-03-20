// lib/ui/theme/sao_theme.dart
import 'package:flutter/material.dart';
import 'sao_colors.dart';
import 'sao_radii.dart';
import 'sao_spacing.dart';

/// Theme completo de SAO (compartido entre Mobile y Desktop)
/// Este ThemeData debe usarse en MaterialApp para garantizar consistencia
class SaoTheme {
  SaoTheme._();

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
        backgroundColor: SaoColors.gray50,
        selectedColor: SaoColors.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          side: const BorderSide(color: SaoColors.border),
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
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
