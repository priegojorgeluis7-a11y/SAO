// lib/ui/helpers/sao_platform.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Helper para detectar plataforma y ajustar comportamiento
class SaoPlatform {
  SaoPlatform._();

  // ============================================================
  // DETECCIÓN DE PLATAFORMA
  // ============================================================
  
  /// Es plataforma desktop (Windows, macOS, Linux)
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Es plataforma mobile (Android, iOS)
  static bool get isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Es Windows
  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// Es macOS
  static bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// Es Linux
  static bool get isLinux {
    if (kIsWeb) return false;
    return Platform.isLinux;
  }

  /// Es Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Es iOS
  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  /// Es Web
  static bool get isWeb => kIsWeb;

  // ============================================================
  // UI/UX ADAPTATIVO
  // ============================================================
  
  /// Densidad visual según plataforma
  /// Desktop usa densidad compacta, mobile usa standard
  static double get visualDensity => isDesktop ? -1.0 : 0.0;

  /// Espaciado base según plataforma
  /// Desktop usa menos espacios, mobile más generoso
  static double get baseSpacing => isDesktop ? 8.0 : 16.0;

  /// Padding de página según plataforma
  static double get pagePadding => isDesktop ? 16.0 : 20.0;

  /// Radio de bordes según plataforma
  static double get borderRadius => isDesktop ? 8.0 : 12.0;

  /// Tamaño de fuente base (escala)
  static double get fontScale => isDesktop ? 0.95 : 1.0;

  /// Altura de AppBar según plataforma
  static double get appBarHeight => isDesktop ? 56.0 : 64.0;

  /// Mostrar tooltips (solo en desktop normalmente)
  static bool get showTooltips => isDesktop;

  /// Ancho máximo de contenido (para desktop)
  static double get maxContentWidth => 1400.0;

  /// Breakpoint para considerar pantalla "grande"
  static double get largeScreenBreakpoint => 1024.0;

  // ============================================================
  // CAPACIDADES DE PLATAFORMA
  // ============================================================
  
  /// Soporta atajos de teclado (principalmente desktop)
  static bool get supportsKeyboardShortcuts => isDesktop;

  /// Soporta arrastrar y soltar (drag & drop)
  static bool get supportsDragAndDrop => isDesktop;

  /// Soporta múltiples ventanas
  static bool get supportsMultipleWindows => isDesktop;

  /// Soporta menú contextual (click derecho)
  static bool get supportsContextMenu => isDesktop;

  /// Soporta hover effects
  static bool get supportsHover => isDesktop;

  /// Tiene teclado físico (probablemente)
  static bool get hasPhysicalKeyboard => isDesktop;

  /// Tiene pantalla táctil (probablemente)
  static bool get hasTouchScreen => isMobile;

  // ============================================================
  // HELPERS DE COMPORTAMIENTO
  // ============================================================
  
  /// Obtener texto para botón "Guardar" según plataforma
  /// Desktop: "Guardar (Ctrl+S)", Mobile: "Guardar"
  static String getSaveButtonText({bool showShortcut = true}) {
    if (!isDesktop || !showShortcut) return 'Guardar';
    return isWindows ? 'Guardar (Ctrl+S)' : 'Guardar (⌘S)';
  }

  /// Obtener tecla modificadora principal
  /// Windows/Linux: Ctrl, macOS: Command
  static String get primaryModifier => isMacOS ? '⌘' : 'Ctrl';

  /// Nombre de la plataforma para display
  static String get platformName {
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  // ============================================================
  // LAYOUT HELPERS
  // ============================================================
  
  /// Determinar si usar layout de 1, 2 o 3 columnas según ancho
  static int getColumnCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 3;
  }

  /// Es pantalla pequeña
  static bool isSmallScreen(double width) => width < 600;

  /// Es pantalla mediana
  static bool isMediumScreen(double width) => width >= 600 && width < 900;

  /// Es pantalla grande  
  static bool isLargeScreen(double width) => width >= 900;

  /// Es pantalla extra grande
  static bool isExtraLargeScreen(double width) => width >= 1200;
}
