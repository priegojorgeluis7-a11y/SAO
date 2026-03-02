// lib/ui/theme/sao_layout.dart
import 'package:flutter/widgets.dart';
import 'sao_spacing.dart';

/// Breakpoints y helpers responsivos de SAO
/// Garantiza layouts consistentes en mobile, tablet y desktop
class SaoBreakpoints {
  SaoBreakpoints._();
  
  static const mobile = 600.0;    // 0-600px: Mobile (1 columna)
  static const tablet = 1024.0;   // 600-1024px: Tablet (2 columnas)
  static const desktop = 1440.0;  // 1024-1440px: Desktop (3+ columnas)
  static const wide = 1920.0;     // 1440+: Wide desktop (4+ columnas)
}

/// Helpers para diseño responsivo
class SaoLayout {
  SaoLayout._();

  // ============================================================
  // DETECCIÓN DE DISPOSITIVO
  // ============================================================
  
  /// Obtiene el ancho de la pantalla
  static double width(BuildContext context) => MediaQuery.of(context).size.width;

  /// Verifica si es mobile (< 600px)
  static bool isMobile(BuildContext context) => 
    width(context) < SaoBreakpoints.mobile;

  /// Verifica si es tablet (600-1024px)
  static bool isTablet(BuildContext context) {
    final w = width(context);
    return w >= SaoBreakpoints.mobile && w < SaoBreakpoints.desktop;
  }

  /// Verifica si es desktop (>= 1024px)
  static bool isDesktop(BuildContext context) => 
    width(context) >= SaoBreakpoints.desktop;

  /// Verifica si es wide desktop (>= 1920px)
  static bool isWide(BuildContext context) => 
    width(context) >= SaoBreakpoints.wide;

  // ============================================================
  // HELPERS DE LAYOUT
  // ============================================================
  
  /// Obtiene número de columnas según ancho de pantalla
  static int getColumns(BuildContext context) {
    final w = width(context);
    if (w < SaoBreakpoints.mobile) return 1;
    if (w < SaoBreakpoints.tablet) return 2;
    if (w < SaoBreakpoints.desktop) return 3;
    if (w < SaoBreakpoints.wide) return 4;
    return 6;
  }

  /// Obtiene padding de página responsivo
  static double getPagePadding(BuildContext context) {
    if (isMobile(context)) return SaoSpacing.lg;
    if (isTablet(context)) return SaoSpacing.xl;
    return SaoSpacing.xxl;
  }
}
