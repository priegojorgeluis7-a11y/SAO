// lib/ui/theme/sao_motion.dart
import 'package:flutter/animation.dart';

/// Sistema de animaciones consistente de SAO
/// Duraciones y curvas estandarizadas para motion design profesional
class SaoMotion {
  SaoMotion._();

  // ============================================================
  // DURACIONES
  // ============================================================
  static const instant = Duration(milliseconds: 100);  // Feedback inmediato
  static const fast = Duration(milliseconds: 150);     // Transiciones rápidas
  static const normal = Duration(milliseconds: 250);   // Animaciones estándar
  static const slow = Duration(milliseconds: 400);     // Animaciones complejas
  static const slower = Duration(milliseconds: 600);   // Transiciones de página

  // ============================================================
  // CURVAS DE ANIMACIÓN
  // ============================================================
  static const easeOut = Curves.easeOutCubic;          // Salida suave (default)
  static const easeIn = Curves.easeInCubic;            // Entrada suave
  static const easeInOut = Curves.easeInOutCubic;      // Suave ambos lados
  static const bounce = Curves.elasticOut;             // Efecto rebote
  static const sharp = Curves.easeOutExpo;             // Agresivo/rápido
}
