// lib/ui/theme/sao_spacing.dart

/// Espaciado centralizado de SAO
/// ⚠️ NO uses valores numéricos directos, usa SOLO estos tokens
class SaoSpacing {
  SaoSpacing._();

  // ============================================================
  // ESPACIADO BASE (múltiplos de 4)
  // ============================================================
  static const double xxs = 2.0;   // Extra extra small
  static const double xs = 4.0;    // Extra small
  static const double sm = 8.0;    // Small
  static const double md = 12.0;   // Medium
  static const double lg = 16.0;   // Large
  static const double xl = 20.0;   // Extra large
  static const double xxl = 24.0;  // Extra extra large
  static const double xxxl = 32.0; // Triple extra large

  // ============================================================
  // PADDING DE CONTENEDORES
  // ============================================================
  static const double cardPadding = 12.0;
  static const double pagePadding = 20.0;
  static const double dialogPadding = 24.0;

  // ============================================================
  // SEPARACIÓN ENTRE ELEMENTOS
  // ============================================================
  static const double listItemGap = 8.0;
  static const double sectionGap = 16.0;
  static const double pageGap = 24.0;
}
